# ===========================================
# STAGE 3: VSCode/Cursor Configuration
# ===========================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ===========================================
# Functions
# ===========================================
function Write-Step { param([string]$Message); Write-Host "`n>> $Message" -ForegroundColor Green }
function Write-Info { param([string]$Message); Write-Host "   $Message" -ForegroundColor Gray }
function Write-Success { param([string]$Message); Write-Host "   [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message); Write-Host "   [!] $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message); Write-Host "   [X] $Message" -ForegroundColor Red }

# ===========================================
# Header
# ===========================================
Clear-Host
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  VSCode/Cursor Configuration" -ForegroundColor Cyan
Write-Host "  Stage 3: Extensions & Settings" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# ===========================================
# Stage 2 Verification
# ===========================================
# Don't declare victory over a failed Ubuntu setup: verify stage2-ubuntu.sh
# actually reached its shell-configuration step before promising the user
# that newweb/newpy/newgo/newrust exist.
Write-Step "Verifying Stage 2 (Ubuntu setup)..."
$stage2Complete = $false
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$check = (& wsl.exe -- bash -c "grep -q '# Development Environment Configuration' ~/.bashrc && echo STAGE2_OK" 2>&1) | ForEach-Object { "$_" -replace "`0", "" }
$ErrorActionPreference = $prevEAP
if ($check -contains "STAGE2_OK") {
    $stage2Complete = $true
    Write-Success "Stage 2 completed - shell environment found"
} else {
    Write-Warn "Stage 2 (stage2-ubuntu.sh) does not appear to have completed!"
    Write-Info "Shell commands like newgo/newweb will be missing until it finishes."
    Write-Info "Recommended: run 'bash stage2-ubuntu.sh' in Ubuntu first."
    $continue = Read-Host "   Continue with VSCode setup anyway? [y/N]"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Info "Exiting - run stage2-ubuntu.sh, then re-run this script."
        exit 0
    }
}

# ===========================================
# Interactive Selection
# ===========================================
Write-Host ""
Write-Host "   Select extension categories to install:" -ForegroundColor Yellow
Write-Host ""

$INSTALL_PYTHON = $true
$INSTALL_GO = $true
$INSTALL_RUST = $false
$INSTALL_JS = $true
$INSTALL_AI = $true
$INSTALL_DEVOPS = $false

$response = Read-Host "   Install Python extensions? [Y/n]"
if ($response -eq "n" -or $response -eq "N") { $INSTALL_PYTHON = $false }

$response = Read-Host "   Install Go extensions? [Y/n]"
if ($response -eq "n" -or $response -eq "N") { $INSTALL_GO = $false }

$response = Read-Host "   Install Rust extensions? (rust-analyzer, LLDB debugger) [y/N]"
if ($response -eq "y" -or $response -eq "Y") { $INSTALL_RUST = $true }

$response = Read-Host "   Install JavaScript/React extensions? [Y/n]"
if ($response -eq "n" -or $response -eq "N") { $INSTALL_JS = $false }

$response = Read-Host "   Install AI extensions? (Claude, Copilot) [Y/n]"
if ($response -eq "n" -or $response -eq "N") { $INSTALL_AI = $false }

$response = Read-Host "   Install DevOps extensions? (Docker, YAML, K8s) [y/N]"
if ($response -eq "y" -or $response -eq "Y") { $INSTALL_DEVOPS = $true }

# ===========================================
# Editor Detection
# ===========================================
Write-Step "Detecting editors..."

$editors = @()

if (Get-Command code -ErrorAction SilentlyContinue) {
    $editors += @{
        Name = "VSCode"
        Command = "code"
        ConfigPath = "$env:APPDATA\Code\User"
        ServerDir = ".vscode-server"
    }
    Write-Success "VSCode detected"
}

if (Get-Command cursor -ErrorAction SilentlyContinue) {
    $editors += @{
        Name = "Cursor"
        Command = "cursor"
        ConfigPath = "$env:APPDATA\Cursor\User"
        ServerDir = ".cursor-server"
    }
    Write-Success "Cursor detected"
}

if ($editors.Count -eq 0) {
    Write-Err "No editor found. Please install VSCode or Cursor first."
    Write-Info "VSCode: https://code.visualstudio.com/"
    Write-Info "Cursor: https://cursor.sh/"
    Read-Host "Press Enter to continue" | Out-Null
    exit 1
}

if ($editors.Count -gt 1) {
    Write-Host ""
    Write-Host "   Configure which editor?" -ForegroundColor Yellow
    Write-Host "   1. VSCode only"
    Write-Host "   2. Cursor only"
    Write-Host "   3. Both"
    $choice = Read-Host "   Choice (1/2/3)"
    
    switch ($choice) {
        "1" { $editors = @($editors | Where-Object { $_.Name -eq "VSCode" }) }
        "2" { $editors = @($editors | Where-Object { $_.Name -eq "Cursor" }) }
    }
}

# ===========================================
# Build Extensions List Based on Selection
# ===========================================
$extensions = [ordered]@{
    
    # ===== CORE (Always) =====
    "Core" = @(
        "ms-vscode-remote.remote-wsl"              # WSL Integration
        "ms-vscode-remote.remote-ssh"              # SSH Remote
    )
    
    # ===== GIT (Always) =====
    "Git" = @(
        "eamodio.gitlens"                          # Git supercharged
        "mhutchie.git-graph"                       # Git graph
    )
    
    # ===== CODE QUALITY (Always) =====
    "Code Quality" = @(
        "usernamehw.errorlens"                     # Inline errors
        "esbenp.prettier-vscode"                   # Formatter
        "editorconfig.editorconfig"                # EditorConfig
        "streetsidesoftware.code-spell-checker"    # Spell checker (cSpell settings)
    )
    
    # ===== PRODUCTIVITY (Always) =====
    "Productivity" = @(
        "christian-kohler.path-intellisense"       # Path autocomplete
        "Gruntfuggly.todo-tree"                    # TODO tracker
        "alefragnani.project-manager"              # Project manager
        "mikestead.dotenv"                         # .env syntax (files.associations)
    )
    
    # ===== THEMES (Always) =====
    "Themes" = @(
        "PKief.material-icon-theme"                # Icons
        "github.github-vscode-theme"               # GitHub theme
    )
    
    # ===== SCRIPTING (Always) =====
    "Scripting" = @(
        "ms-vscode.powershell"                     # PowerShell
        "ms-vscode.makefile-tools"                 # Makefile
        "timonwong.shellcheck"                     # Shell script linting
        "foxundermoon.shell-format"                # Shell script formatting
    )
    
    # ===== DOCS (Always) =====
    # Both are referenced by settings.json ([markdown] / [yaml] formatters)
    "Docs" = @(
        "yzhang.markdown-all-in-one"               # Markdown formatter/tools
        "redhat.vscode-yaml"                       # YAML support
    )
}

# Add Python if selected
if ($INSTALL_PYTHON) {
    $extensions["Python"] = @(
        "ms-python.python"
        "ms-python.vscode-pylance"
        "ms-python.black-formatter"
        "charliermarsh.ruff"
        "ms-python.debugpy"
        "ms-toolsai.jupyter"
    )
}

# Add Go if selected
if ($INSTALL_GO) {
    $extensions["Go"] = @(
        "golang.go"
    )
}

# Add Rust if selected
if ($INSTALL_RUST) {
    $extensions["Rust"] = @(
        "rust-lang.rust-analyzer"                  # Language server
        "vadimcn.vscode-lldb"                      # CodeLLDB debugger
        "tamasfe.even-better-toml"                 # Cargo.toml support
    )
}

# Add JavaScript/React if selected
if ($INSTALL_JS) {
    $extensions["JavaScript"] = @(
        "dbaeumer.vscode-eslint"
        "dsznajder.es7-react-js-snippets"
        "formulahendry.auto-rename-tag"
        "burkeholland.simple-react-snippets"
        "styled-components.vscode-styled-components"
        "wix.vscode-import-cost"
    )
    $extensions["HTML/CSS"] = @(
        "bradlc.vscode-tailwindcss"
        "ritwickdey.liveserver"
        "pranaygp.vscode-css-peek"
        "naumovs.color-highlight"
    )
}

# Add AI if selected
if ($INSTALL_AI) {
    $extensions["AI"] = @(
        "anthropic.claude-code"
        "github.copilot"
        "github.copilot-chat"
    )
}

# Add DevOps if selected
if ($INSTALL_DEVOPS) {
    $extensions["DevOps"] = @(
        "ms-azuretools.vscode-docker"
        "tamasfe.even-better-toml"
        "ms-kubernetes-tools.vscode-kubernetes-tools"
    )
}

# ===========================================
# Settings Definition
# ===========================================
$settings = @'
{
    // ===========================================
    // EDITOR
    // ===========================================
    "editor.fontSize": 14,
    "editor.fontFamily": "'JetBrainsMono Nerd Font', 'JetBrains Mono', 'Cascadia Code', Consolas, monospace",
    "editor.fontLigatures": true,
    "editor.lineHeight": 1.6,
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.detectIndentation": true,
    "editor.wordWrap": "off",
    "editor.cursorBlinking": "smooth",
    "editor.cursorSmoothCaretAnimation": "on",
    "editor.smoothScrolling": true,
    "editor.minimap.enabled": false,
    "editor.renderWhitespace": "selection",
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.bracketPairs": "active",
    "editor.linkedEditing": true,
    "editor.suggest.preview": true,
    "editor.suggest.showMethods": true,
    "editor.suggest.showFunctions": true,
    "editor.inlineSuggest.enabled": true,
    "editor.formatOnSave": true,
    "editor.formatOnPaste": false,
    "editor.codeActionsOnSave": {
        "source.fixAll": "explicit",
        "source.organizeImports": "explicit",
        "source.addMissingImports": "explicit"
    },
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.quickSuggestions": {
        "strings": "on"
    },
    "editor.stickyScroll.enabled": true,
    "editor.unicodeHighlight.allowedLocales": {
        "he": true
    },

    // ===========================================
    // FILES
    // ===========================================
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.trimFinalNewlines": true,
    "files.eol": "\n",
    "files.exclude": {
        "**/.git": true,
        "**/.DS_Store": true,
        "**/node_modules": true,
        "**/__pycache__": true,
        "**/.pytest_cache": true,
        "**/.venv": true,
        "**/venv": true,
        "**/*.pyc": true,
        "**/.next": true,
        "**/dist": true,
        "**/coverage": true
    },
    "files.watcherExclude": {
        "**/node_modules/**": true,
        "**/.venv/**": true,
        "**/venv/**": true,
        "**/.git/objects/**": true,
        "**/dist/**": true
    },
    "files.associations": {
        "*.css": "tailwindcss",
        ".env*": "dotenv"
    },

    // ===========================================
    // WORKBENCH
    // ===========================================
    "workbench.startupEditor": "none",
    "workbench.iconTheme": "material-icon-theme",
    "workbench.colorTheme": "GitHub Dark Default",
    "workbench.tree.indent": 16,
    "workbench.editor.enablePreview": false,
    "workbench.editor.tabSizing": "shrink",
    "workbench.sideBar.location": "left",
    "workbench.activityBar.location": "default",
    "workbench.list.smoothScrolling": true,

    // ===========================================
    // TERMINAL
    // ===========================================
    "terminal.integrated.defaultProfile.windows": "Ubuntu",
    "terminal.integrated.fontSize": 14,
    "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font', 'JetBrains Mono', 'Cascadia Code', monospace",
    "terminal.integrated.cursorBlinking": true,
    "terminal.integrated.cursorStyle": "line",
    "terminal.integrated.smoothScrolling": true,
    "terminal.integrated.enableMultiLinePasteWarning": "never",

    // ===========================================
    // EXPLORER
    // ===========================================
    "explorer.confirmDelete": false,
    "explorer.confirmDragAndDrop": false,
    "explorer.compactFolders": false,
    "explorer.sortOrder": "type",
    "explorer.fileNesting.enabled": true,
    "explorer.fileNesting.patterns": {
        "package.json": "package-lock.json, yarn.lock, pnpm-lock.yaml, bun.lockb, .npmrc, .yarnrc*",
        "tsconfig.json": "tsconfig.*.json, env.d.ts",
        ".eslintrc*": ".eslintignore, .prettierrc*, .prettierignore",
        "*.ts": "${capture}.test.ts, ${capture}.spec.ts",
        "*.tsx": "${capture}.test.tsx, ${capture}.spec.tsx",
        "*.js": "${capture}.test.js, ${capture}.spec.js"
    },

    // ===========================================
    // GIT
    // ===========================================
    "git.autofetch": true,
    "git.confirmSync": false,
    "git.enableSmartCommit": true,
    "git.openRepositoryInParentFolders": "always",
    "git.inputValidation": true,
    "gitlens.hovers.currentLine.over": "line",
    "gitlens.codeLens.enabled": false,

    // ===========================================
    // PYTHON
    // ===========================================
    "[python]": {
        "editor.defaultFormatter": "charliermarsh.ruff",
        "editor.formatOnSave": true,
        "editor.tabSize": 4,
        "editor.codeActionsOnSave": {
            "source.fixAll": "explicit",
            "source.organizeImports": "explicit"
        }
    },
    "python.analysis.typeCheckingMode": "basic",
    "python.analysis.autoImportCompletions": true,
    "python.analysis.inlayHints.functionReturnTypes": true,
    "python.analysis.inlayHints.variableTypes": true,
    "ruff.organizeImports": true,

    // ===========================================
    // JAVASCRIPT/TYPESCRIPT
    // ===========================================
    "[javascript]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.tabSize": 2
    },
    "[typescript]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.tabSize": 2
    },
    "[typescriptreact]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.tabSize": 2
    },
    "[javascriptreact]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.tabSize": 2
    },
    "typescript.updateImportsOnFileMove.enabled": "always",
    "javascript.updateImportsOnFileMove.enabled": "always",
    "typescript.preferences.importModuleSpecifier": "relative",
    "typescript.suggest.autoImports": true,
    "typescript.inlayHints.parameterNames.enabled": "all",
    "typescript.inlayHints.functionLikeReturnTypes.enabled": true,

    // ===========================================
    // JSON
    // ===========================================
    "[json]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.tabSize": 2
    },
    "[jsonc]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.tabSize": 2
    },

    // ===========================================
    // HTML/CSS
    // ===========================================
    "[html]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.tabSize": 2
    },
    "[css]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.tabSize": 2
    },
    "[tailwindcss]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode"
    },
    "tailwindCSS.emmetCompletions": true,
    "tailwindCSS.includeLanguages": {
        "typescript": "javascript",
        "typescriptreact": "javascript"
    },

    // ===========================================
    // GO
    // ===========================================
    "[go]": {
        "editor.defaultFormatter": "golang.go",
        "editor.formatOnSave": true,
        "editor.tabSize": 4,
        "editor.insertSpaces": false
    },
    "go.useLanguageServer": true,
    "go.lintTool": "golangci-lint",
    "go.lintOnSave": "package",
    "gopls": {
        "ui.semanticTokens": true
    },

    // ===========================================
    // RUST
    // ===========================================
    "[rust]": {
        "editor.defaultFormatter": "rust-lang.rust-analyzer",
        "editor.formatOnSave": true,
        "editor.tabSize": 4
    },
    "rust-analyzer.check.command": "clippy",

    // ===========================================
    // MARKDOWN
    // ===========================================
    "[markdown]": {
        "editor.wordWrap": "on",
        "editor.defaultFormatter": "yzhang.markdown-all-in-one",
        "editor.formatOnSave": false
    },

    // ===========================================
    // YAML
    // ===========================================
    "[yaml]": {
        "editor.tabSize": 2,
        "editor.defaultFormatter": "redhat.vscode-yaml"
    },

    // ===========================================
    // EXTENSIONS
    // ===========================================
    
    // Error Lens
    "errorLens.enabledDiagnosticLevels": ["error", "warning"],
    "errorLens.delay": 300,
    "errorLens.fontStyleItalic": true,

    // Todo Tree
    "todo-tree.general.tags": ["TODO", "FIXME", "BUG", "HACK", "NOTE", "XXX", "REVIEW"],
    "todo-tree.highlights.defaultHighlight": {
        "gutterIcon": true,
        "foreground": "#fff",
        "iconColour": "#ffab00"
    },

    // Prettier
    "prettier.semi": true,
    "prettier.singleQuote": true,
    "prettier.trailingComma": "es5",
    "prettier.tabWidth": 2,
    "prettier.printWidth": 100,
    "prettier.bracketSpacing": true,
    "prettier.arrowParens": "avoid",
    "prettier.jsxSingleQuote": false,

    // Import Cost
    "importCost.smallPackageSize": 10,
    "importCost.mediumPackageSize": 50,
    "importCost.largePackageColor": "#d44e40",

    // Spell Checker
    "cSpell.language": "en",
    "cSpell.enableFiletypes": ["markdown", "plaintext", "typescript", "javascript"],

    // Live Server
    "liveServer.settings.donotShowInfoMsg": true,

    // Remote WSL
    "remote.WSL.fileWatcher.polling": false,
    "remote.autoForwardPorts": true,

    // ===========================================
    // AI ASSISTANTS
    // ===========================================
    "github.copilot.enable": {
        "*": true,
        "plaintext": false,
        "markdown": true,
        "yaml": true
    },

    // ===========================================
    // EMMET
    // ===========================================
    "emmet.triggerExpansionOnTab": true,
    "emmet.includeLanguages": {
        "javascript": "javascriptreact",
        "typescript": "typescriptreact"
    }
}
'@

# ===========================================
# Install Extensions
# ===========================================
# De-duplicate the flattened extension list (some ids, e.g.
# tamasfe.even-better-toml, appear in more than one category) so we neither
# double-count nor double-install them.
$allExtensions = $extensions.Values | ForEach-Object { $_ } | Select-Object -Unique
$totalExtensions = $allExtensions.Count

# Split the list by where each extension actually needs to RUN. UI extensions
# (the Remote-* clients and the theme/icon packs) run on the Windows side and
# have no useful remote copy - installing Remote-WSL into the WSL server even
# errors. Everything else is a "workspace" extension (language servers, linters,
# formatters, debuggers, git tooling) that ONLY functions when installed inside
# the WSL remote, so those get pushed to the WSL server further below.
$uiOnlyExtensions = @(
    "ms-vscode-remote.remote-wsl"
    "ms-vscode-remote.remote-ssh"
    "PKief.material-icon-theme"
    "github.github-vscode-theme"
)
$wslExtensions = $allExtensions | Where-Object { $uiOnlyExtensions -notcontains $_ }

foreach ($editor in $editors) {
    # This box keeps Windows CLEAN by design: only UI extensions install locally
    # - the Remote-WSL / Remote-SSH connectors (which pull in Remote Explorer and
    # remote-ssh-edit as dependencies) and the theme/icon packs. Every dev
    # extension (language servers, linters, formatters, debuggers) goes into the
    # WSL remote instead, in the step below. Installing those locally too would
    # just be inert clutter that has to be cleaned off later.
    Write-Step "Installing UI extensions locally (Windows) for $($editor.Name)..."

    $cmd = $editor.Command
    $failed = @()

    foreach ($ext in $uiOnlyExtensions) {
        try {
            # code.cmd prints update notices to stderr; with EAP=Stop that
            # would throw under 2>&1, so relax it just for this native call
            $prevEAP = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $result = & $cmd --install-extension $ext --force 2>&1
            $ErrorActionPreference = $prevEAP

            if ($LASTEXITCODE -eq 0) {
                Write-Host "      [OK] $ext" -ForegroundColor Green
            } else {
                $failed += $ext
                Write-Host "      [!] $ext" -ForegroundColor Yellow
                Write-Info $result
            }
        } catch {
            $failed += $ext
            Write-Host "      [X] $ext" -ForegroundColor Red
        }
    }

    $installedCount = $uiOnlyExtensions.Count - $failed.Count
    Write-Success "$installedCount of $($uiOnlyExtensions.Count) UI extensions installed locally (Windows) for $($editor.Name)"

    if ($failed.Count -gt 0) {
        Write-Warn "Some local extensions need manual installation:"
        $failed | ForEach-Object { Write-Info "  - $_" }
    }

    # ===========================================
    # Push workspace extensions into the WSL server
    # ===========================================
    # Language servers / linters / formatters / debuggers only run when they
    # live in the WSL remote (they were deliberately NOT installed locally
    # above). There is exactly one mechanism that
    # reliably installs into the remote from a detached (non-interactive) shell:
    #   - `code --install-extension` on Windows has no --remote flag, so it can
    #     only ever hit the local Windows install.
    #   - `wsl code --install-extension` resolves `code` to the Windows launcher
    #     via interop -> installs LOCALLY while returning exit 0 (false success).
    #   - the server's `bin/<commit>/bin/remote-cli/code` needs a live VS Code
    #     terminal's IPC socket; from a plain wsl.exe call it errors out.
    #   - the server's `bin/<commit>/bin/code-server --install-extension` works
    #     headlessly and targets the WSL server. That is what we use here.
    # code-server only exists once VS Code has provisioned the server, i.e. after
    # you've opened a WSL folder at least once; if it's missing we say so plainly
    # instead of pretending the workspace extensions made it across.
    Write-Step "Installing workspace extensions into WSL for $($editor.Name)..."
    $serverDir = $editor.ServerDir

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $raw = (& wsl.exe -- bash -c "ls -t `$HOME/$serverDir/bin/*/bin/code-server 2>/dev/null | head -1" 2>&1) |
        ForEach-Object { "$_" -replace "`0", "" }
    $serverBin = ($raw | Where-Object { $_ -match '/code-server$' } | Select-Object -First 1)
    if ($serverBin) { $serverBin = $serverBin.Trim() }

    if (-not $serverBin) {
        $ErrorActionPreference = $prevEAP
        Write-Warn "WSL server for $($editor.Name) not found - workspace extensions NOT installed in WSL."
        Write-Info "The remote server is only created the first time you open a WSL folder."
        Write-Info "To finish: open Ubuntu, run '$($editor.Command) .' once to provision it, then re-run this script."
        Write-Info "Until then these run on Windows only and will NOT work in a WSL workspace:"
        $wslExtensions | ForEach-Object { Write-Info "  - $_" }
    } else {
        Write-Info "Server: $serverBin"
        $wslFailed = @()
        foreach ($ext in $wslExtensions) {
            $out = & wsl.exe -- bash -c "'$serverBin' --install-extension '$ext' --force" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      [OK] $ext (WSL)" -ForegroundColor Green
            } else {
                $wslFailed += $ext
                Write-Host "      [!] $ext (WSL)" -ForegroundColor Yellow
                Write-Info ($out -join " ")
            }
        }
        $ErrorActionPreference = $prevEAP
        if ($wslFailed.Count -eq 0) {
            Write-Success "$($wslExtensions.Count) workspace extensions installed into WSL for $($editor.Name)"
        } else {
            Write-Warn "Some WSL extensions failed - re-run, or add them via 'Install in WSL' in VS Code:"
            $wslFailed | ForEach-Object { Write-Info "  - $_" }
        }
    }
}

# ===========================================
# Apply Settings
# ===========================================
Write-Step "Applying settings..."

foreach ($editor in $editors) {
    $configPath = $editor.ConfigPath
    $settingsPath = "$configPath\settings.json"
    
    # Create directory
    if (-not (Test-Path $configPath)) {
        New-Item -ItemType Directory -Path $configPath -Force | Out-Null
    }
    
    # Backup existing
    if (Test-Path $settingsPath) {
        $backup = "$settingsPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $settingsPath $backup
        Write-Info "Backed up: $backup"
    }
    
    # Write settings as BOM-free UTF-8. Windows PowerShell 5.1's
    # `-Encoding UTF8` prepends a UTF-8 BOM, which some parsers mis-read
    # (the ADR-2 hazard). Note: these local user settings DO apply inside
    # Remote-WSL sessions, so no WSL-side copy is needed (that would just
    # create a second, drift-prone source of truth).
    [System.IO.File]::WriteAllText($settingsPath, $settings, (New-Object System.Text.UTF8Encoding($false)))
    Write-Success "$($editor.Name) settings applied"
}

# ===========================================
# Create Project Templates
# ===========================================
Write-Step "Creating project templates..."

$templatesPath = "$env:USERPROFILE\WSL-Reference\templates"
New-Item -ItemType Directory -Path $templatesPath -Force | Out-Null

# Write templates as BOM-free UTF-8 (matching settings.json). PowerShell 5.1's
# `Out-File -Encoding UTF8` prepends a UTF-8 BOM, which breaks parsers like
# EditorConfig (a leading BOM turns `root = true` into an unrecognized key) and
# would also emit CRLF line endings, contradicting `end_of_line = lf`.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# .prettierrc
$prettierrc = @'
{
    "semi": true,
    "singleQuote": true,
    "trailingComma": "es5",
    "tabWidth": 2,
    "printWidth": 100,
    "bracketSpacing": true,
    "arrowParens": "avoid",
    "endOfLine": "lf"
}
'@
[System.IO.File]::WriteAllText("$templatesPath\.prettierrc", $prettierrc, $utf8NoBom)

# .editorconfig
$editorconfig = @'
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{py,go,rs}]
indent_size = 4

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
'@
[System.IO.File]::WriteAllText("$templatesPath\.editorconfig", $editorconfig, $utf8NoBom)

# .gitignore
$gitignore = @'
# Dependencies
node_modules/
.pnpm-store/
__pycache__/
*.pyc
.venv/
venv/

# Build
target/
dist/
build/
.next/
out/
coverage/

# IDE
.idea/
.vscode/
*.swp
*.swo
.DS_Store

# Environment
.env
.env.local
.env*.local

# Logs
*.log
npm-debug.log*
yarn-debug.log*
pnpm-debug.log*

# Testing
coverage/
.nyc_output/
'@
[System.IO.File]::WriteAllText("$templatesPath\.gitignore", $gitignore, $utf8NoBom)

Write-Success "Templates created in: $templatesPath"

# ===========================================
# Summary
# ===========================================
# $totalExtensions already holds the de-duped count of selected ids from above.

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  STAGE 3 COMPLETE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Extensions selected: $totalExtensions" -ForegroundColor White
Write-Host ""
Write-Host "  Categories:" -ForegroundColor Gray

foreach ($category in $extensions.Keys) {
    $count = $extensions[$category].Count
    Write-Host "    - ${category}: $count" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  Templates: $templatesPath" -ForegroundColor Gray
Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  SETUP COMPLETE!" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Your development environment is ready!" -ForegroundColor Green
Write-Host ""
Write-Host "  Quick Start:" -ForegroundColor Cyan
Write-Host "    1. Open Ubuntu terminal" -ForegroundColor White
Write-Host "    2. cd ~/projects/sandbox" -ForegroundColor White
Write-Host "    3. code ." -ForegroundColor White
Write-Host ""
Write-Host "  Create new projects:" -ForegroundColor Cyan
if (-not $stage2Complete) {
    Write-Host ""
    Write-Host "  NOTE: Stage 2 was incomplete - the commands below will only" -ForegroundColor Yellow
    Write-Host "  work after stage2-ubuntu.sh finishes successfully." -ForegroundColor Yellow
}
Write-Host "    newweb myapp    # React + TypeScript + Vite" -ForegroundColor White
Write-Host "    newpy myapp     # Python + venv + uv" -ForegroundColor White
Write-Host "    newgo myapp     # Go module" -ForegroundColor White
Write-Host "    newrust myapp   # Rust crate (cargo new)" -ForegroundColor White
Write-Host ""
Write-Host "  Font: JetBrainsMono Nerd Font (installed by stage0-winget.ps1 Stage 0)" -ForegroundColor Gray
Write-Host "    Needed for starship/eza/lazygit icons - already set in settings.json" -ForegroundColor Gray
Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to continue" | Out-Null
