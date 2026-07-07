# ===========================================
# WSL Management Tools
# Version: 4.3 - Production Grade
# ===========================================

param(
    [Parameter(Position=0)]
    [ValidateSet("backup", "restore", "status", "clean", "reset", "update", "help")]
    [string]$Action = "help"
)

$ErrorActionPreference = "Stop"

# wsl.exe's OWN subcommands (--list/--version/--status) emit UTF-16 (LE) with
# embedded nulls. Do NOT force [Console]::OutputEncoding globally: that would also
# mangle the UTF-8 passthrough from 'wsl -- <linux cmd>' (e.g. apt output, which
# would render as garbage). Instead, every site that parses or displays wsl.exe's
# own output strips the residual nulls locally (see Get-WSLDistros / Get-WSLStatus).

# ===========================================
# Functions
# ===========================================
function Write-Step { param([string]$Message); Write-Host "`n>> $Message" -ForegroundColor Green }
function Write-Info { param([string]$Message); Write-Host "   $Message" -ForegroundColor Gray }
function Write-Success { param([string]$Message); Write-Host "   [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message); Write-Host "   [!] $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message); Write-Host "   [X] $Message" -ForegroundColor Red }

# With $ErrorActionPreference = 'Stop', benign native-command stderr (e.g. wsl.exe
# progress noise) is promoted to a terminating error. Run native calls through here
# so real exit codes surface via $LASTEXITCODE without stderr aborting the tool.
function Invoke-Native {
    param([scriptblock]$Command)
    # A passed scriptblock is lexically bound to its defining scope, so it resolves
    # $ErrorActionPreference up through the script scope - override there, not locally.
    $prev = $script:ErrorActionPreference
    $script:ErrorActionPreference = 'Continue'
    try {
        & $Command
    } finally {
        $script:ErrorActionPreference = $prev
    }
}

# Always return an ARRAY of distro names. A single distro must not degrade to a
# scalar string (indexing a string yields characters, not the name). Strip any
# residual UTF-16 nulls and trim as belt-and-suspenders.
function Get-WSLDistros {
    return @(Invoke-Native { wsl --list --quiet } |
        ForEach-Object { ($_ -replace "`0", "").Trim() } |
        Where-Object { $_ -ne "" })
}

# Discover ext4.vhdx files. Authoritative source is the Lxss registry (each distro
# records its BasePath); fall back to well-known install locations.
function Get-WSLVhdPaths {
    $paths = @()

    $lxssRoot = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    if (Test-Path $lxssRoot) {
        Get-ChildItem $lxssRoot -ErrorAction SilentlyContinue | ForEach-Object {
            $basePath = (Get-ItemProperty -Path $_.PSPath -Name BasePath -ErrorAction SilentlyContinue).BasePath
            if ($basePath) {
                $basePath = $basePath -replace '^\\\\\?\\', ''
                $vhd = Join-Path $basePath "ext4.vhdx"
                if (Test-Path $vhd) { $paths += Get-Item $vhd }
            }
        }
    }

    if ($paths.Count -eq 0) {
        $patterns = @(
            "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.Ubuntu*\LocalState\ext4.vhdx",
            "$env:LOCALAPPDATA\WSL\*\ext4.vhdx"
        )
        foreach ($pattern in $patterns) {
            $paths += Get-ChildItem $pattern -ErrorAction SilentlyContinue
        }
    }

    return @($paths | Where-Object { $_ } | Sort-Object FullName -Unique)
}

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  WSL Management Tools v4.3" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
}

function Show-Help {
    Show-Header
    Write-Host ""
    Write-Host "Usage: .\wsl-tools.ps1 <action>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  status   - Show WSL status, versions, and disk usage"
    Write-Host "  backup   - Create a backup of Ubuntu"
    Write-Host "  restore  - Restore Ubuntu from a backup"
    Write-Host "  clean    - Clean up to free disk space"
    Write-Host "  reset    - Complete reset (reinstall Ubuntu)"
    Write-Host "  update   - Update WSL kernel and Ubuntu packages"
    Write-Host "  help     - Show this help"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\wsl-tools.ps1 status"
    Write-Host "  .\wsl-tools.ps1 backup"
    Write-Host "  .\wsl-tools.ps1 clean"
    Write-Host ""
}

function Get-WSLStatus {
    Show-Header
    Write-Step "WSL Status"
    
    # WSL Version
    Write-Host "   WSL Version:" -ForegroundColor Yellow
    $wslVersion = @(Invoke-Native { wsl --version 2>$null } |
        ForEach-Object { ($_ -replace "`0", "").TrimEnd() } |
        Where-Object { $_ -ne "" })
    if ($wslVersion) {
        $wslVersion | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    } else {
        Write-Info "      Could not get WSL version"
    }

    # Distributions
    Write-Host ""
    Write-Host "   Distributions:" -ForegroundColor Yellow
    Invoke-Native { wsl --list --verbose } |
        ForEach-Object { ($_ -replace "`0", "").TrimEnd() } |
        Where-Object { $_ -ne "" } |
        ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    
    # Disk Usage
    Write-Host ""
    Write-Host "   Disk Usage:" -ForegroundColor Yellow
    
    $vhdFiles = Get-WSLVhdPaths
    if ($vhdFiles.Count -gt 0) {
        foreach ($vhd in $vhdFiles) {
            $sizeGB = [math]::Round($vhd.Length / 1GB, 2)
            Write-Host "      $($vhd.FullName): $sizeGB GB" -ForegroundColor Gray
        }
    } else {
        Write-Info "      No virtual disks found"
    }
    
    # Memory Config
    Write-Host ""
    Write-Host "   Resource Limits (.wslconfig):" -ForegroundColor Yellow
    $wslConfig = "$env:USERPROFILE\.wslconfig"
    if (Test-Path $wslConfig) {
        Get-Content $wslConfig | Where-Object { $_ -match "^[^#\[]" -and $_.Trim() -ne "" } | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Gray
        }
    } else {
        Write-Info "      No .wslconfig (using defaults)"
    }
    
    # Running processes
    Write-Host ""
    Write-Host "   Running Processes:" -ForegroundColor Yellow
    # vmmemWSL / vmmem is the actual WSL2 VM; wsl/wslhost/wslservice are host helpers
    $wslProc = Get-Process -Name "vmmemWSL", "vmmem", "wsl", "wslhost", "wslservice" -ErrorAction SilentlyContinue
    if ($wslProc) {
        $totalMem = ($wslProc | Measure-Object -Property WorkingSet64 -Sum).Sum / 1GB
        Write-Host "      WSL memory (VM + helpers): $([math]::Round($totalMem, 2)) GB" -ForegroundColor Gray
    } else {
        Write-Info "      WSL not running"
    }
    
    Write-Host ""
}

function Backup-WSL {
    Show-Header
    Write-Step "WSL Backup"
    
    # Create backup directory
    $backupDir = "$env:USERPROFILE\WSL-Backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    
    # Get distribution name
    $distros = Get-WSLDistros

    if ($distros.Count -eq 0) {
        Write-Err "No WSL distributions found"
        return
    }

    if ($distros.Count -gt 1) {
        Write-Host "   Available distributions:" -ForegroundColor Yellow
        $i = 1
        foreach ($d in $distros) {
            Write-Host "      $i. $d" -ForegroundColor Gray
            $i++
        }
        $selection = Read-Host "   Select (1-$($distros.Count))"
        if ($selection -notmatch '^\d+$' -or [int]$selection -lt 1 -or [int]$selection -gt $distros.Count) {
            Write-Err "Invalid selection"
            return
        }
        $distro = $distros[[int]$selection - 1]
    } else {
        $distro = $distros[0]
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = "$backupDir\$distro-$timestamp.tar"
    
    Write-Info "Distribution: $distro"
    Write-Info "Backup file: $backupFile"
    Write-Host ""
    
    # Shutdown WSL
    Write-Info "Shutting down WSL..."
    Invoke-Native { wsl --shutdown }
    Start-Sleep -Seconds 3

    # Export
    Write-Info "Creating backup (this may take several minutes)..."
    Write-Host ""

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-Native { wsl --export $distro $backupFile }
    $stopwatch.Stop()

    if ($LASTEXITCODE -ne 0) {
        Write-Err "Export failed (exit $LASTEXITCODE)"
        # A failed export can leave a truncated/corrupt .tar behind. Remove it so a
        # later 'restore' can't mistake it for a good backup and wipe the live distro.
        if (Test-Path $backupFile) {
            Remove-Item $backupFile -Force -ErrorAction SilentlyContinue
            Write-Info "Removed partial/corrupt backup file: $backupFile"
        }
        return
    }

    if (Test-Path $backupFile) {
        $sizeGB = [math]::Round((Get-Item $backupFile).Length / 1GB, 2)
        $duration = [math]::Round($stopwatch.Elapsed.TotalMinutes, 1)
        
        Write-Success "Backup created: $backupFile"
        Write-Info "Size: $sizeGB GB"
        Write-Info "Duration: $duration minutes"
        
        # Cleanup old backups (keep last 3) - scoped to THIS distro only
        Write-Host ""
        Write-Host "   Existing backups:" -ForegroundColor Yellow
        $backups = @(Get-ChildItem "$backupDir\$distro-*.tar" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        
        foreach ($b in $backups) {
            $size = [math]::Round($b.Length / 1GB, 2)
            $date = $b.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
            Write-Host "      $($b.Name) - $size GB ($date)" -ForegroundColor Gray
        }
        
        if ($backups.Count -gt 3) {
            Write-Host ""
            $toDelete = $backups | Select-Object -Skip 3
            $deleteSize = [math]::Round(($toDelete | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
            $response = Read-Host "   Delete $($toDelete.Count) old backups ($deleteSize GB)? (y/n)"
            if ($response -match '^\s*y') {
                $toDelete | Remove-Item -Force
                Write-Success "Old backups deleted"
            }
        }
    } else {
        Write-Err "Backup failed"
    }
    
    Write-Host ""
}

function Restore-WSL {
    Show-Header
    Write-Step "WSL Restore"
    
    $backupDir = "$env:USERPROFILE\WSL-Backups"
    
    if (-not (Test-Path $backupDir)) {
        Write-Err "No backup directory found"
        return
    }
    
    $backups = @(Get-ChildItem "$backupDir\*.tar" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)

    if ($backups.Count -eq 0) {
        Write-Err "No backups found in $backupDir"
        return
    }
    
    Write-Host "   Available backups:" -ForegroundColor Yellow
    $i = 1
    foreach ($b in $backups) {
        $size = [math]::Round($b.Length / 1GB, 2)
        $date = $b.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        Write-Host "      $i. $($b.Name) - $size GB ($date)" -ForegroundColor Gray
        $i++
    }
    
    Write-Host ""
    $selection = Read-Host "   Select backup (1-$($backups.Count)) or 'q' to quit"
    
    if ($selection -eq 'q') { return }

    if ($selection -notmatch '^\d+$' -or [int]$selection -lt 1 -or [int]$selection -gt $backups.Count) {
        Write-Err "Invalid selection"
        return
    }
    $selectedBackup = $backups[[int]$selection - 1]

    if (-not (Test-Path $selectedBackup.FullName)) {
        Write-Err "Backup file not found: $($selectedBackup.FullName)"
        return
    }

    # Validate the tar BEFORE we destroy anything: a real WSL export is large, so a
    # tiny/empty file is a truncated or corrupt backup. Refuse it here so we never
    # unregister the live distro only to fail the import from a bad archive.
    $minBackupBytes = 300KB
    if ($selectedBackup.Length -lt $minBackupBytes) {
        $kb = [math]::Round($selectedBackup.Length / 1KB, 1)
        Write-Err "Backup file is only $kb KB - it looks truncated or corrupt."
        Write-Err "Aborting: your current distro has NOT been touched."
        return
    }

    # Extract distro name from filename
    $distroName = $selectedBackup.BaseName -replace "-\d{8}-\d{6}$", ""

    Write-Host ""
    Write-Warn "This will REPLACE your current $distroName installation!"
    Write-Host ""
    $confirm = Read-Host "   Type '$distroName' to confirm"

    if ($confirm -ne $distroName) {
        Write-Info "Cancelled."
        return
    }

    Write-Host ""
    Write-Info "Shutting down WSL..."
    Invoke-Native { wsl --shutdown }
    Start-Sleep -Seconds 3

    if ((Get-WSLDistros) -contains $distroName) {
        Write-Info "Unregistering $distroName..."
        Invoke-Native { wsl --unregister $distroName 2>$null }
    } else {
        Write-Warn "$distroName is not currently registered; skipping unregister."
    }

    $installPath = "$env:LOCALAPPDATA\WSL\$distroName"
    if (-not (Test-Path $installPath)) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    }

    Write-Info "Importing backup (this may take several minutes)..."
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-Native { wsl --import $distroName $installPath $selectedBackup.FullName }
    $stopwatch.Stop()

    if ($LASTEXITCODE -ne 0) {
        Write-Err "Import FAILED (exit $LASTEXITCODE)."
        Write-Err "The previous '$distroName' distro was already unregistered."
        Write-Err "Your backup is still safe at: $($selectedBackup.FullName)"
        return
    }

    Write-Success "Restore complete!"
    Write-Info "Duration: $([math]::Round($stopwatch.Elapsed.TotalMinutes, 1)) minutes"
    
    # 'wsl --import' always sets the default user to root - fix it
    Write-Host ""
    $wslUser = Read-Host "   Enter your Ubuntu username to set as default (or leave empty to skip)"
    if ($wslUser) {
        if ($wslUser -notmatch '^[a-z_][a-z0-9_-]*$') {
            Write-Err "Invalid username '$wslUser' (must match ^[a-z_][a-z0-9_-]`$). Skipping."
        } else {
            # WSL 2.x one-liner; falls back to editing /etc/wsl.conf on older versions
            Invoke-Native { wsl --manage $distroName --set-default-user $wslUser 2>$null }
            if ($LASTEXITCODE -ne 0) {
                # Idempotent: drop any existing default= line, ensure a [user] section,
                # then set default= exactly once (preserves other wsl.conf content).
                $confScript = 'conf=/etc/wsl.conf; touch "$conf"; sed -i ''/^default=/d'' "$conf"; grep -q ''^\[user\]'' "$conf" || printf ''\n[user]\n'' >> "$conf"; sed -i ''/^\[user\]/a default=__USER__'' "$conf"'
                $confScript = $confScript -replace '__USER__', $wslUser
                Invoke-Native { wsl -d $distroName -u root -- bash -c $confScript }
                Invoke-Native { wsl --shutdown }
            }
            Write-Success "Default user set to: $wslUser"
        }
    } else {
        Write-Warn "Default user is root. Set it later with:"
        Write-Info "   wsl --manage $distroName --set-default-user YOUR_USERNAME"
    }
    Write-Host ""
}

function Clean-WSL {
    Show-Header
    Write-Step "WSL Cleanup"
    
    Write-Host "   This will:" -ForegroundColor Yellow
    Write-Host "      1. Clear apt cache" -ForegroundColor Gray
    Write-Host "      2. Remove unused packages" -ForegroundColor Gray
    Write-Host "      3. Clear temp files" -ForegroundColor Gray
    Write-Host "      4. Compact virtual disk" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "   Continue? (y/n)"
    if ($confirm -ne "y") { return }
    
    Write-Host ""
    
    # Get initial size. The cleanup below runs in the DEFAULT distro (all 'wsl -- ...'
    # calls have no -d), so compact THAT distro's VHD - not an arbitrary first-by-name
    # one. Resolve the default distro's ext4.vhdx from the Lxss registry.
    $vhdPath = $null
    $lxssRoot = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    if (Test-Path $lxssRoot) {
        $defaultGuid = (Get-ItemProperty -Path $lxssRoot -Name DefaultDistribution -ErrorAction SilentlyContinue).DefaultDistribution
        if ($defaultGuid) {
            $distroKey = Join-Path $lxssRoot $defaultGuid
            $basePath = (Get-ItemProperty -Path $distroKey -Name BasePath -ErrorAction SilentlyContinue).BasePath
            if ($basePath) {
                $basePath = $basePath -replace '^\\\\\?\\', ''
                $vhd = Join-Path $basePath "ext4.vhdx"
                if (Test-Path $vhd) { $vhdPath = Get-Item $vhd }
            }
        }
    }
    # Fall back to previous behavior only if the registry lookup didn't resolve.
    if (-not $vhdPath) { $vhdPath = Get-WSLVhdPaths | Select-Object -First 1 }

    $sizeBefore = if ($vhdPath) { [math]::Round($vhdPath.Length / 1GB, 2) } else { 0 }

    # Clean inside WSL
    Write-Info "Cleaning apt cache..."
    Invoke-Native { wsl -u root -- apt clean }

    Write-Info "Removing unused packages..."
    Invoke-Native { wsl -u root -- apt autoremove -y }

    # Route through a shell so globs and ~ expand (plain 'wsl -- rm' does not).
    # /tmp is system-wide (clean as root); the user's caches must run as the
    # DEFAULT user so ~ resolves to their home, not root's.
    Write-Info "Clearing temp files..."
    Invoke-Native { wsl -u root -- bash -c 'rm -rf /tmp/* 2>/dev/null' }

    Write-Info "Clearing user caches (~/.cache, cargo)..."
    Invoke-Native { wsl -- bash -c 'rm -rf ~/.cache/* ~/.cargo/registry/cache 2>/dev/null' }

    # npm/pnpm are loaded by nvm in the *interactive* .bashrc, so they are not
    # on PATH for plain 'wsl --' commands - run them through an interactive shell
    Write-Info "Clearing npm cache..."
    Invoke-Native { wsl -- bash -ic "npm cache clean --force" 2>$null }

    Write-Info "Clearing pnpm cache..."
    Invoke-Native { wsl -- bash -ic "pnpm store prune" 2>$null }

    # Shutdown
    Write-Info "Shutting down WSL..."
    Invoke-Native { wsl --shutdown }
    Start-Sleep -Seconds 5
    
    # Compact VHD
    if ($vhdPath -and (Test-Path $vhdPath.FullName)) {
        Write-Info "Compacting virtual disk..."
        
        # Check if running as admin for diskpart
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        if ($isAdmin) {
            $diskpartScript = @"
select vdisk file="$($vhdPath.FullName)"
compact vdisk
exit
"@
            Invoke-Native { $diskpartScript | diskpart 2>$null }
            
            $sizeAfter = [math]::Round((Get-Item $vhdPath.FullName).Length / 1GB, 2)
            $saved = [math]::Round($sizeBefore - $sizeAfter, 2)
            
            Write-Success "Disk compacted: $sizeBefore GB -> $sizeAfter GB (saved $saved GB)"
        } else {
            Write-Warn "Run as Administrator to compact disk"
            Write-Info "Current size: $sizeBefore GB"
        }
    }
    
    Write-Host ""
    Write-Success "Cleanup complete!"
    Write-Host ""
}

function Reset-WSL {
    Show-Header
    Write-Step "WSL Reset"

    # Pick which installed distro to reset (do not hardcode 'Ubuntu')
    $distros = Get-WSLDistros
    if ($distros.Count -eq 0) {
        Write-Err "No WSL distributions found"
        return
    }

    if ($distros.Count -gt 1) {
        Write-Host "   Installed distributions:" -ForegroundColor Yellow
        $i = 1
        foreach ($d in $distros) {
            Write-Host "      $i. $d" -ForegroundColor Gray
            $i++
        }
        $selection = Read-Host "   Select distribution to reset (1-$($distros.Count))"
        if ($selection -notmatch '^\d+$' -or [int]$selection -lt 1 -or [int]$selection -gt $distros.Count) {
            Write-Err "Invalid selection"
            return
        }
        $distro = $distros[[int]$selection - 1]
    } else {
        $distro = $distros[0]
    }

    # 'wsl --install -d' takes an ONLINE CATALOG name, which is not the same
    # namespace as the REGISTERED name from 'wsl --list --quiet'. A distro created
    # via 'wsl --import' (e.g. by this tool's restore) has no catalog entry and
    # cannot be reinstalled this way. Verify installability BEFORE unregistering so
    # reset can never leave the machine distro-less.
    $onlineNames = @(Invoke-Native { wsl --list --online 2>$null } |
        ForEach-Object { ($_ -replace "`0", "").Trim() } |
        Where-Object { $_ -ne "" } |
        ForEach-Object { ($_ -split '\s+')[0] })
    if ($onlineNames -notcontains $distro) {
        Write-Err "'$distro' is not available in the WSL online catalog (wsl --list --online)."
        Write-Err "It was likely created via 'wsl --import' and can't be auto-reinstalled."
        Write-Err "Aborting reset so your distro is NOT removed. Back it up and reinstall manually if needed."
        return
    }

    Write-Host ""
    Write-Warn "This will COMPLETELY REMOVE $distro and all data!"
    Write-Host ""
    Write-Host "   You will lose:" -ForegroundColor Red
    Write-Host "      - All projects in ~/projects" -ForegroundColor Gray
    Write-Host "      - All installed packages" -ForegroundColor Gray
    Write-Host "      - All configuration" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Make sure you have a backup!" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "   Type 'DELETE' to confirm"

    if ($confirm -ne "DELETE") {
        Write-Info "Cancelled"
        return
    }

    Write-Host ""
    Write-Info "Shutting down WSL..."
    Invoke-Native { wsl --shutdown }
    Start-Sleep -Seconds 3

    Write-Info "Unregistering $distro..."
    Invoke-Native { wsl --unregister $distro }

    Write-Info "Reinstalling $distro..."
    Invoke-Native { wsl --install -d $distro --no-launch }
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Reinstall FAILED (exit $LASTEXITCODE). '$distro' was unregistered but not reinstalled."
        Write-Err "Install it manually: wsl --install -d $distro"
        return
    }

    Write-Host ""
    Write-Success "Reset complete!"
    Write-Host ""
    Write-Info "Open $distro from Start Menu to complete setup"
    Write-Info "Then run stage2-ubuntu.sh again"
    Write-Host ""
}

function Update-WSL {
    Show-Header
    Write-Step "WSL Update"
    
    # Update WSL kernel
    Write-Info "Updating WSL..."
    Invoke-Native { wsl --update }

    # Update Ubuntu packages
    Write-Host ""
    Write-Info "Updating Ubuntu packages..."
    Invoke-Native { wsl -u root -- apt update }
    Invoke-Native { wsl -u root -- apt upgrade -y }
    Invoke-Native { wsl -u root -- apt autoremove -y }
    
    Write-Host ""
    Write-Success "Update complete!"
    Write-Host ""
}

# ===========================================
# Main
# ===========================================
switch ($Action) {
    "status"  { Get-WSLStatus }
    "backup"  { Backup-WSL }
    "restore" { Restore-WSL }
    "clean"   { Clean-WSL }
    "reset"   { Reset-WSL }
    "update"  { Update-WSL }
    "help"    { Show-Help }
    default   { Show-Help }
}
