# ===========================================
# Windows App Bootstrap (winget)  -  "Stage 0"
# ===========================================
# Installs the Windows-side apps for a WSL2 dev machine, then hand off to
# stage1-windows.ps1. Idempotent: anything already installed is skipped.
#
# Run (it self-elevates; machine-scope installers like Git/PowerToys need admin):
#   powershell -ExecutionPolicy Bypass -File .\stage0-winget.ps1
#
# Toggle a group off by setting its variable to $false below.

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ----- self-elevate: machine-scope installers need admin, and
# --disable-interactivity suppresses winget's own UAC prompt, so a non-elevated
# run would silently fail those. Relaunch elevated once (single UAC prompt). -----
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    try {
        Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"" `
            -Verb RunAs
    } catch {
        Write-Host "Administrator rights are required. Right-click -> Run as administrator." -ForegroundColor Red
        Read-Host "Press Enter to close"
    }
    exit
}

# ----- what to install (flip any to $false to skip that group) -----
$InstallBrowsers   = $true
$InstallEditors    = $true    # VS Code
$InstallTerminal   = $true    # Windows Terminal, PowerShell 7, gsudo
$InstallDevTools   = $true    # Git for Windows, PowerToys
$InstallUtilities  = $true    # Everything, Notepad++, WinRAR, Snipping Tool
$InstallAI         = $true    # Claude
$InstallPackageMgr = $true    # Chocolatey, UniGetUI
$InstallNerdFont   = $true    # JetBrainsMono Nerd Font (icons for starship/eza/lazygit)

# ----- pretty output -----
function Write-Head($m) { Write-Host "`n>> $m" -ForegroundColor Green }
function Write-Info($m) { Write-Host "   $m"   -ForegroundColor Gray }
function Write-Ok($m)   { Write-Host "   [OK] $m"   -ForegroundColor Green }
function Write-Skip($m) { Write-Host "   [--] $m (already installed)" -ForegroundColor DarkGray }
function Write-Warn($m) { Write-Host "   [!] $m"    -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "   [X] $m"    -ForegroundColor Red }

# Install a Nerd Font system-wide from the official Nerd Fonts release. winget /
# Store coverage for Nerd Fonts is unreliable (worse on debloated images), so we
# download the zip directly. Requires admin (system Fonts + HKLM) - the script
# self-elevates above. Idempotent: skips if already installed.
function Install-NerdFont {
    param([string]$Family = "JetBrainsMono")
    $fontsDir = Join-Path $env:WINDIR "Fonts"
    if (Get-ChildItem $fontsDir -Filter "${Family}NerdFont*.ttf" -ErrorAction SilentlyContinue) {
        Write-Skip "$Family Nerd Font"; return
    }
    Write-Info "Downloading $Family Nerd Font..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $zip = Join-Path $env:TEMP "$Family-NF.zip"
    $dir = Join-Path $env:TEMP "$Family-NF"
    $prevPP = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"   # PS 5.1: the IWR progress bar is ~10x slower
    try {
        Invoke-WebRequest -UseBasicParsing `
            -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$Family.zip" `
            -OutFile $zip
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $dir -Force
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $count = 0
        Get-ChildItem $dir -Filter "*.ttf" | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $fontsDir $_.Name) -Force
            New-ItemProperty -Path $regPath -Name "$($_.BaseName) (TrueType)" `
                -Value $_.Name -PropertyType String -Force | Out-Null
            $count++
        }
        Remove-Item $zip, $dir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "$Family Nerd Font ($count styles)"
    } catch {
        Write-Warn "Nerd Font download failed: $($_.Exception.Message)"
        Write-Info "Fallback: set the terminal font to 'Cascadia Code NF' (ships with Windows Terminal)."
    } finally {
        $ProgressPreference = $prevPP
    }
}

try {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Windows App Bootstrap (winget)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    # ----- winget must exist AND actually run -----
    # Get-Command alone is not enough: debloated images often leave only the App
    # Execution Alias stub while App Installer itself is removed, so the alias
    # resolves but every invocation fails. Probe `winget --version` and parse it;
    # that both proves winget runs and lets us gate newer-only flags below.
    $wingetVersion = $null
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            $vRaw = (winget --version 2>$null | Select-Object -First 1)
            if ($LASTEXITCODE -eq 0 -and $vRaw) {
                # output looks like "v1.7.10861" - grab the numeric version
                $m = [regex]::Match([string]$vRaw, '\d+(\.\d+){1,3}')
                if ($m.Success) { $wingetVersion = [version]$m.Value }
            }
        } catch { }
    }
    if (-not $wingetVersion) {
        Write-Err "winget (App Installer) is not available or not working."
        Write-Info "Install or repair 'App Installer' from the Microsoft Store, then re-run this script:"
        Write-Info "  https://apps.microsoft.com/detail/9nblggh4nns1"
        exit 1
    }
    # --disable-interactivity was added in winget 1.4; older builds reject it as an
    # unknown argument, which would make every install fail. Gate it on version.
    $supportsNoInteractive = $wingetVersion -ge [version]"1.4.0"
    # Accept source agreements once up front so per-package installs are quiet.
    winget list --accept-source-agreements 1>$null 2>$null

    # ----- app catalog: Id | Name | Group -----
    # 'have' = already on this user's current machine (kept so the script
    # reproduces it); recommended additions are marked in the Name.
    $apps = @(
        # Browsers
        @{ Id = "Brave.Brave";                    Name = "Brave";                    Group = "Browsers"  }
        # Editors
        @{ Id = "Microsoft.VisualStudioCode";     Name = "VS Code";                  Group = "Editors"   }
        # AI
        @{ Id = "Anthropic.Claude";               Name = "Claude";                   Group = "AI"        }
        # Terminal & shell
        @{ Id = "Microsoft.WindowsTerminal";      Name = "Windows Terminal  (+)";    Group = "Terminal"  }
        @{ Id = "Microsoft.PowerShell";           Name = "PowerShell 7";             Group = "Terminal"  }
        @{ Id = "gerardog.gsudo";                 Name = "gsudo (sudo for Windows) (+)"; Group = "Terminal" }
        # Dev tools
        @{ Id = "Git.Git";                        Name = "Git for Windows  (+)";     Group = "DevTools"  }
        @{ Id = "Microsoft.PowerToys";            Name = "PowerToys  (+)";           Group = "DevTools"  }
        # Utilities
        @{ Id = "voidtools.Everything";           Name = "Everything";               Group = "Utilities" }
        @{ Id = "Notepad++.Notepad++";            Name = "Notepad++";                Group = "Utilities" }
        @{ Id = "RARLab.WinRAR";                  Name = "WinRAR";                   Group = "Utilities" }
        # Snipping Tool: re-added because Windows X Lite (debloated) strips it.
        # Store app -> install from msstore by product id; it reports as
        # Microsoft.ScreenSketch once present, so check under that id.
        @{ Id = "9MZ95KL8MR0L"; CheckId = "Microsoft.ScreenSketch"; Source = "msstore"; Name = "Snipping Tool  (+)"; Group = "Utilities" }
        # Windows App (successor to Microsoft Remote Desktop): Store-only, so
        # install via its msstore product id. Not an inbox app, so winget lists
        # it under that same product id once present - default CheckId is fine.
        @{ Id = "9N1F85V9T8BN"; Source = "msstore"; Name = "Windows App"; Group = "Utilities" }
        # Package managers
        @{ Id = "Chocolatey.Chocolatey";          Name = "Chocolatey";               Group = "PackageMgr" }
        @{ Id = "MartiCliment.UniGetUI";          Name = "UniGetUI";                 Group = "PackageMgr" }
    )

    $enabled = @{
        Browsers   = $InstallBrowsers
        Editors    = $InstallEditors
        Terminal   = $InstallTerminal
        DevTools   = $InstallDevTools
        Utilities  = $InstallUtilities
        AI         = $InstallAI
        PackageMgr = $InstallPackageMgr
    }

    $installed = 0; $skipped = 0; $failed = @()

    foreach ($group in ($apps.Group | Select-Object -Unique)) {
        if (-not $enabled[$group]) { continue }
        Write-Head $group
        foreach ($app in ($apps | Where-Object { $_.Group -eq $group })) {
            # Idempotent: is it already installed? Some Store apps report under a
            # different package id than their msstore product id - use CheckId.
            $checkId = if ($app.CheckId) { $app.CheckId } else { $app.Id }
            $source  = if ($app.Source)  { $app.Source }  else { "winget" }
            winget list --id $checkId --exact --accept-source-agreements 1>$null 2>$null
            if ($LASTEXITCODE -eq 0) { Write-Skip $app.Name; $skipped++; continue }

            Write-Info "Installing $($app.Name)..."
            # EAP relaxed: winget writes progress/notices to stderr which would
            # otherwise throw under Stop.
            $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
            $wingetArgs = @(
                "install", "--id", $app.Id, "--exact", "--source", $source, "--silent",
                "--accept-package-agreements", "--accept-source-agreements"
            )
            if ($supportsNoInteractive) { $wingetArgs += "--disable-interactivity" }
            winget @wingetArgs 2>&1 | Out-Null
            $code = $LASTEXITCODE
            $ErrorActionPreference = $prevEAP

            # winget returns nonzero for several NON-failure outcomes. $LASTEXITCODE
            # arrives as a signed Int32, so normalize to the unsigned HRESULT first.
            # Documented codes we accept (learn.microsoft.com winget return codes):
            #   0x8A15010D INSTALL_ALREADY_INSTALLED, 0x8A150014 UPDATE_NOT_APPLICABLE -> success
            #   0x8A150109/010A/010B reboot-required/initiated + MSI 3010/1641      -> success (reboot)
            $ucode = [uint32]([int64]$code -band 0xFFFFFFFF)
            $benignCodes = @(0x8A15010D, 0x8A150014)
            $rebootCodes = @(0x8A150109, 0x8A15010A, 0x8A15010B, 3010, 1641)

            if ($code -eq 0 -or $benignCodes -contains $ucode) { Write-Ok $app.Name; $installed++ }
            elseif ($rebootCodes -contains $ucode) { Write-Ok "$($app.Name) (reboot required to finish)"; $installed++ }
            else { $failed += $app.Name; Write-Warn "$($app.Name) (winget exit $code)" }
        }
    }

    # ----- Nerd Font (needed for the WSL CLI icons) -----
    if ($InstallNerdFont) {
        Write-Head "Nerd Font"
        Install-NerdFont -Family "JetBrainsMono"
        Write-Info "Set it in Windows Terminal: Settings -> your WSL profile -> Appearance"
        Write-Info "-> Font face -> 'JetBrainsMono Nerd Font' (or 'JetBrainsMono NF Mono')."
    }

    # ----- summary -----
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "  Done: $installed installed, $skipped already present" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    if ($failed.Count -gt 0) {
        Write-Warn "These need a manual look:"
        $failed | ForEach-Object { Write-Info "  - $_" }
        if ($failed -contains "Snipping Tool  (+)") {
            Write-Info "  (Snipping Tool comes from the Microsoft Store; debloated 'X Lite'"
            Write-Info "   images sometimes remove the Store engine. Reinstall it via winget's"
            Write-Info "   msstore source, or add the Store back, then re-run.)"
        }
    }
    Write-Info "Next: run stage1-windows.ps1 (elevated) to enable WSL2."
}
catch {
    Write-Err $_.Exception.Message
    Write-Info $_.ScriptStackTrace
}
finally {
    Read-Host "`nPress Enter to close"
}
