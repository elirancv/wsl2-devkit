# ===========================================
# STAGE 1: WSL2 Installation & Configuration
# Run as Administrator
# ===========================================

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Safe wrapper for wsl.exe:
# - native stderr under 2>$null with EAP=Stop throws NativeCommandError in
#   PS 5.1, so relax EAP locally and capture both streams
# - wsl.exe emits UTF-16LE in Windows PowerShell 5.1. Setting the console
#   OutputEncoding to Unicode makes PS decode it correctly AND consumes the
#   leading BOM; we still strip any stray null / BOM (U+FEFF) chars so an exact
#   match such as `-notcontains "Ubuntu"` (used on the second run) stays reliable.
function Invoke-Wsl {
    param([string[]]$Arguments)
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $prevOutEnc = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    try {
        $output = (& wsl.exe @Arguments 2>&1) |
            ForEach-Object { "$_" -replace "`0", "" -replace ([char]0xFEFF), "" }
        $exitCode = $LASTEXITCODE
    } finally {
        [Console]::OutputEncoding = $prevOutEnc
        $ErrorActionPreference = $prevEAP
    }
    return [PSCustomObject]@{ Output = ($output -join "`n"); Lines = $output; ExitCode = $exitCode }
}

# ===========================================
# Logging & Output Functions
# ===========================================
function Write-Step { 
    param([string]$Message)
    Write-Host "`n>> $Message" -ForegroundColor Green
}

function Write-Info { 
    param([string]$Message)
    Write-Host "   $Message" -ForegroundColor Gray 
}

function Write-Success { 
    param([string]$Message)
    Write-Host "   [OK] $Message" -ForegroundColor Green 
}

function Write-Warn { 
    param([string]$Message)
    Write-Host "   [!] $Message" -ForegroundColor Yellow 
}

function Write-Err {
    param([string]$Message)
    Write-Host "   [X] $Message" -ForegroundColor Red
}

# Release version = latest git tag when run from a clone; empty for ZIP
# downloads (no .git) or when git is missing. History: CHANGELOG.md / tags.
$DevkitVersion = ""
try {
    $tag = git -C $PSScriptRoot describe --tags 2>$null
    if ($LASTEXITCODE -eq 0 -and $tag) { $DevkitVersion = " $tag" }
} catch { }
# git exits 128 when there's no repo/tags; don't let that leak as the script's
# exit code (CI's shell wrapper ends with `exit $LASTEXITCODE`)
$global:LASTEXITCODE = 0

try {

# ===========================================
# Header
# ===========================================
Clear-Host
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  WSL2 Development Environment$DevkitVersion" -ForegroundColor Cyan
Write-Host "  Stage 1: Windows Configuration" -ForegroundColor Cyan
Write-Host "  Supports: Windows 10 (2004+) & Windows 11" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# ===========================================
# System Validation
# ===========================================
Write-Step "Validating system requirements..."

# Windows version check
$osVersion = [System.Environment]::OSVersion.Version
$minBuild = 19041

if ($osVersion.Build -lt $minBuild) {
    Write-Err "Windows 10 version 2004+ or Windows 11 required"
    Write-Info "Your build: $($osVersion.Build) (minimum: $minBuild)"
    Write-Info "Please run Windows Update first"
    exit 1   # the outer finally{} owns the single pause
}

# Detect Windows version for display
$winVersion = if ($osVersion.Build -ge 22000) { "Windows 11" } else { "Windows 10" }
Write-Success "$winVersion detected (Build $($osVersion.Build))"

# RAM check
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
Write-Success "System RAM: ${totalRAM}GB"

# Disk space check
$systemDrive = Get-PSDrive ($env:SystemDrive.TrimEnd(':'))
$freeSpaceGB = [math]::Round($systemDrive.Free / 1GB)
if ($freeSpaceGB -lt 20) {
    Write-Warn "Low disk space: ${freeSpaceGB}GB free (recommend 20GB+)"
} else {
    Write-Success "Disk space: ${freeSpaceGB}GB free"
}

# Virtualization check (HypervisorPresent is only true when a hypervisor is
# already running, so a 'false' here is expected on first run - just informational)
$hyperv = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty HypervisorPresent
if (-not $hyperv) {
    Write-Info "Hypervisor not active yet - if Stage 1 fails after restart, enable virtualization (VT-x/AMD-V) in BIOS"
}

# ===========================================
# WSL Installation
# ===========================================
Write-Step "Installing WSL2..."

# NOTE: reboot-pending edge case (needs verification on real hardware). This
# relies on the in-process $needsRestart flag only. If the user declines the
# restart and re-runs WITHOUT rebooting, DISM may report State="Enabled" while
# the drivers aren't loaded yet, so $needsRestart=false and the WSL commands
# below can run before the features are truly active (--set-default-version 2
# would then fail). There is no persistent reboot-pending detection.
$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
$vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

if ($wslFeature.State -ne "Enabled" -or $vmFeature.State -ne "Enabled") {
    Write-Info "Enabling Windows features..."
    
    $r1 = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -WarningAction SilentlyContinue
    $r2 = Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -WarningAction SilentlyContinue

    if ($null -ne $r1 -and $null -ne $r2) {
        # Trust the DISM cmdlet's own RestartNeeded rather than assuming
        $needsRestart = [bool]$r1.RestartNeeded -or [bool]$r2.RestartNeeded
    } else {
        # Results unavailable - stay conservative and require a restart
        $needsRestart = $true
    }
    Write-Success "Windows features enabled"
} else {
    Write-Success "WSL features already enabled"
    $needsRestart = $false
}

if ($needsRestart) {
    # WSL commands are unreliable until the newly enabled features are active
    Write-Warn "Restart required before WSL can be configured"
    Write-Info "After the restart, run this script again to install Ubuntu"
} else {
    # The Windows *features* can be enabled while the WSL *package* (MSIX,
    # wsl 2.x) is missing or stale - on modern Win10/11 wsl.exe is just a stub
    # until installed, and a freshly installed package still needs --update.
    # Handle both non-interactively so the user never sees the
    # "Press any key to install" prompt or "must be updated" errors.
    Write-Info "Ensuring WSL core is installed and up to date..."
    Invoke-Wsl @("--install", "--no-distribution") | Out-Null
    $update = Invoke-Wsl @("--update")
    if ($update.ExitCode -eq 0) {
        Write-Success "WSL core up to date"
    } else {
        Write-Warn "wsl --update reported an issue (continuing): $($update.Output)"
    }

    # Set WSL2 as default (retry once after another update if WSL insists)
    $result = Invoke-Wsl @("--set-default-version", "2")
    if ($result.ExitCode -ne 0 -and $result.Output -match "update") {
        Write-Info "WSL requested another update - retrying..."
        Invoke-Wsl @("--update") | Out-Null
        $result = Invoke-Wsl @("--set-default-version", "2")
    }
    if ($result.ExitCode -eq 0) {
        Write-Success "WSL2 set as default"
    } else {
        Write-Err "Could not set WSL2 as default: $($result.Output)"
        Write-Info "Try running 'wsl --update' manually, restart, then re-run this script"
        exit 1
    }

    # Install Ubuntu if not present (Invoke-Wsl already strips the UTF-16
    # null chars wsl.exe emits in Windows PowerShell 5.1)
    $distros = (Invoke-Wsl @("--list", "--quiet")).Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($distros -notcontains "Ubuntu") {
        Write-Info "Installing Ubuntu (this may take a few minutes)..."
        $install = Invoke-Wsl @("--install", "-d", "Ubuntu", "--no-launch")
        if ($install.ExitCode -eq 0) {
            Write-Success "Ubuntu installed"
        } else {
            Write-Err "Ubuntu install failed: $($install.Output)"
            exit 1
        }
    } else {
        Write-Success "Ubuntu already installed"
    }
}

# ===========================================
# Hyper-V (optional)
# ===========================================
# Optional and independent of WSL2 - WSL2 only needs VirtualMachinePlatform
# (enabled above). Offered for users who also run Hyper-V VMs. Only available on
# Windows Pro/Enterprise/Education (not Home). Enabling needs a restart, so we
# fold it into the same $needsRestart handling used by the WSL features.
Write-Step "Hyper-V (optional)..."

$hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
if ($null -eq $hyperVFeature) {
    Write-Info "Hyper-V is not available on this Windows edition (needs Pro/Enterprise/Education) - skipping"
} elseif ($hyperVFeature.State -eq "Enabled") {
    Write-Success "Hyper-V already enabled"
} else {
    $answer = Read-Host "   Install Hyper-V? (Hyper-V platform + management tools) [y/N]"
    if ($answer -match '^\s*y') {
        try {
            # -All enables the parent feature plus all its sub-features
            $hv = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -WarningAction SilentlyContinue
            if ($null -ne $hv -and $hv.RestartNeeded) { $needsRestart = $true }
            Write-Success "Hyper-V enabled (restart required to activate)"
        } catch {
            Write-Warn "Could not enable Hyper-V: $($_.Exception.Message)"
        }
    } else {
        Write-Info "Skipped Hyper-V"
    }
}

# ===========================================
# WSL Configuration (.wslconfig)
# ===========================================
Write-Step "Creating optimized WSL configuration..."

# Calculate optimal resources based on system
# if/elseif (NOT switch): a `switch` with overlapping -ge ranges matches every
# clause and returns an ARRAY (e.g. 16GB -> @("6GB","4GB")), producing an invalid
# `memory=6GB 4GB` that WSL ignores.
$wslMemory = if ($totalRAM -ge 32) { "10GB" }
             elseif ($totalRAM -ge 16) { "6GB" }
             elseif ($totalRAM -ge 8) { "4GB" }
             else { "2GB" }

# Sum across sockets: NumberOfLogicalProcessors is an array on multi-socket boxes
$cpuCount = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
$wslProcessors = [int][math]::Max(2, [math]::Floor($cpuCount / 2))

# NOTE: cross-account elevation edge case (needs verification on real hardware).
# $env:USERPROFILE is the account the elevated process runs AS. If a standard
# user elevated with a *different* admin account's credentials, this writes
# .wslconfig (and the WSL-* dirs below) into the admin profile, and WSL - run by
# the standard user - never reads it. Correct for the common "same user + UAC
# consent" case.
$wslConfigPath = "$env:USERPROFILE\.wslconfig"

# Mirrored networking, DNS tunneling and autoProxy require Windows 11 22H2+
# (build 22621). On Windows 10 they are unsupported and cause WSL warnings.
$isWin11_22H2 = $osVersion.Build -ge 22621

$networkSection = if ($isWin11_22H2) {
@"

# Network settings (Windows 11 22H2+)
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
"@
} else {
@"

# Network: default NAT mode (mirrored networking requires Windows 11 22H2+)
"@
}

$experimentalSection = if ($isWin11_22H2) {
@"

[experimental]
# Automatic memory reclaim
autoMemoryReclaim=gradual

# Sparse VHD - saves disk space
sparseVhd=true

# Fall back gracefully on DNS requests that can't be parsed (needs dnsTunneling)
bestEffortDnsParsing=true
"@
} else {
@"

[experimental]
# Automatic memory reclaim
autoMemoryReclaim=gradual

# Sparse VHD - saves disk space
sparseVhd=true
"@
}

# Marker kept ASCII-safe on purpose so it survives the ASCII write below and
# can be matched verbatim on subsequent runs
$generatedMarker = "# Generated by wsl2-devkit - safe to edit; regenerated only if this line is absent"

$wslConfigContent = @"
$generatedMarker
# ===========================================
# WSL2 Configuration
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm")
# System: ${totalRAM}GB RAM, ${cpuCount} logical CPUs
# ===========================================

[wsl2]
# Memory allocation (calculated for your system)
memory=$wslMemory

# CPU cores (half of system cores)
processors=$wslProcessors

# Swap file
swap=4GB

# No GUI apps (saves resources)
guiApplications=false

# pageReporting left at its default (on): it's the mechanism that lets the guest
# return freed memory to Windows, so 'autoMemoryReclaim=gradual' below can only
# work with it enabled. Disabling it would pin the VM near its memory cap.
$networkSection
$experimentalSection
"@

$regenerateConfig = $true
if (Test-Path $wslConfigPath) {
    $existingConfig = Get-Content $wslConfigPath -Raw -ErrorAction SilentlyContinue
    if ($existingConfig -notmatch [regex]::Escape($generatedMarker)) {
        # No wsl2-devkit marker -> the user (or another tool) owns this file; leave it alone
        Write-Warn "Existing .wslconfig has no wsl2-devkit marker - keeping your custom config and skipping regeneration"
        $regenerateConfig = $false
    } else {
        $backup = "$wslConfigPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $wslConfigPath $backup
        Write-Info "Backed up existing config to: $backup"

        # Keep only the 3 most recent backups so they don't pile up forever
        Get-ChildItem -Path (Split-Path $wslConfigPath -Parent) -Filter '.wslconfig.backup.*' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 3 |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

if ($regenerateConfig) {
    # ASCII, not UTF8: PS 5.1's UTF8 writes a BOM, which WSL's .wslconfig parser
    # can choke on (the [wsl2] header gets misread and settings are ignored)
    $wslConfigContent | Out-File -FilePath $wslConfigPath -Encoding ASCII -Force
    Write-Success "Created .wslconfig (Memory: $wslMemory, CPUs: $wslProcessors)"
}

# ===========================================
# Directory Structure
# ===========================================
Write-Step "Creating directory structure..."

$directories = @(
    "$env:USERPROFILE\WSL-Backups",
    "$env:USERPROFILE\WSL-Reference"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Success "Created: $dir"
    }
}

# Create reference README
$referenceReadme = @"
# WSL Development Environment Reference

## Access Your Projects

From Windows Explorer, type in address bar:
    \\wsl.localhost\Ubuntu\home\YOUR_USERNAME\projects

## Quick Commands (run in Ubuntu terminal)

    p                    # Go to projects
    gs                   # Git status
    code .               # Open in VSCode
    cursor .             # Open in Cursor

## Important

NEVER store code in this Windows folder.
Always work inside WSL at ~/projects for best performance.
"@

$referenceReadme | Out-File -FilePath "$env:USERPROFILE\WSL-Reference\README.txt" -Encoding ASCII

# ===========================================
# Windows Terminal Settings (if installed)
# ===========================================
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wtSettingsPath) {
    Write-Info "Windows Terminal detected - Ubuntu will be available as a profile"
}

# ===========================================
# Summary
# ===========================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  STAGE 1 COMPLETE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Configuration:" -ForegroundColor White
Write-Host "    Memory Limit:  $wslMemory" -ForegroundColor Gray
Write-Host "    CPU Cores:     $wslProcessors" -ForegroundColor Gray
Write-Host "    Config File:   $wslConfigPath" -ForegroundColor Gray
Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  NEXT STEPS" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""

if ($needsRestart) {
    Write-Host "  1. RESTART your computer (required)" -ForegroundColor White
    Write-Host ""
    Write-Host "  2. After restart, run this script again (as Admin)" -ForegroundColor White
    Write-Host "     It will install Ubuntu now that WSL features are active" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Then open Ubuntu from Start Menu" -ForegroundColor White
    Write-Host "     - Create username (lowercase, no spaces)" -ForegroundColor Gray
    Write-Host "     - Create password (needed for sudo)" -ForegroundColor Gray
} else {
    Write-Host "  1. Open Ubuntu from Start Menu" -ForegroundColor White
    Write-Host "     - Create username (lowercase, no spaces)" -ForegroundColor Gray
    Write-Host "     - Create password (needed for sudo)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  Then: Copy stage2-ubuntu.sh to Ubuntu:" -ForegroundColor White
Write-Host "     Explorer: \\wsl.localhost\Ubuntu\home\USERNAME\" -ForegroundColor Cyan
Write-Host ""
Write-Host "  And run in Ubuntu terminal:" -ForegroundColor White
Write-Host "     chmod +x stage2-ubuntu.sh && ./stage2-ubuntu.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""

if ($needsRestart) {
    $response = Read-Host "Restart now? (y/n)"
    if ($response -match '^\s*y') {
        Write-Info "Restarting in 5 seconds..."
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }
}

}
catch {
    # Any mid-script terminating error lands here instead of slamming the
    # window shut - show what happened before the finally pause
    Write-Err $_.Exception.Message
    Write-Info $_.ScriptStackTrace
}
finally {
    pause
}
