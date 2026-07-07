#!/bin/bash

# ===========================================
# Ubuntu Development Environment Setup
# ===========================================

set -eEuo pipefail

# ===========================================
# Colors
# ===========================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly GRAY='\033[0;90m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ===========================================
# Logging
# ===========================================
log_step() { echo -e "\n${GREEN}>> $1${NC}\n"; }
log_info() { echo -e "${GRAY}   $1${NC}"; }
log_success() { echo -e "${GREEN}   [OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}   [!] $1${NC}"; }
log_error() { echo -e "${RED}   [X] $1${NC}"; }

# ===========================================
# Selection Variables
# ===========================================
INSTALL_NODE=false
INSTALL_PYTHON=false
INSTALL_GO=false
INSTALL_RUST=false
INSTALL_CLI_TOOLS=false
INSTALL_DOCKER_CLI=false
SETUP_GPG=false
GPG_PASSPHRASE_PROTECT=false

# ===========================================
# Arguments (non-interactive support)
# ===========================================
# --yes          accept the defaults (Node/Python/Go/CLI on; Rust/Docker/GPG off)
# --all          install everything (GPG key generated WITHOUT a passphrase -
#                pinentry needs a TTY; protect it later with gpg --passwd)
# --profile F    like --yes, then source F to override selections, e.g.:
#                  INSTALL_RUST=true
#                  SETUP_GPG=false
# In non-interactive mode git identity comes from existing global git config,
# or the GIT_NAME / GIT_EMAIL environment variables.
NONINTERACTIVE=false
ALL_COMPONENTS=false
PROFILE_FILE=""

usage() {
    grep '^# --' "$0" | sed 's/^# /  /'
    echo "  (no flags)     interactive menu"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes)     NONINTERACTIVE=true ;;
        --all)     NONINTERACTIVE=true; ALL_COMPONENTS=true ;;
        --profile) NONINTERACTIVE=true; PROFILE_FILE="${2:-}"; shift
                   [ -f "$PROFILE_FILE" ] || { log_error "profile not found: $PROFILE_FILE"; exit 1; } ;;
        -h|--help) echo "Usage: $0 [--yes|--all|--profile FILE]"; usage; exit 0 ;;
        *)         log_error "unknown option: $1 (see --help)"; exit 1 ;;
    esac
    shift
done

# Pause prompts ("press Enter") become no-ops when non-interactive
pause_enter() { $NONINTERACTIVE || read -r -p "$1" _ || true; }

# ===========================================
# Header
# ===========================================
clear || true   # don't let a missing TTY (piped/CI run) abort under 'set -e'
echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}  Ubuntu Development Environment${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

# ===========================================
# Selection (interactive menu, or flags/profile when non-interactive)
# ===========================================
if $NONINTERACTIVE; then
    # --yes baseline = the same defaults the menu offers
    INSTALL_NODE=true
    INSTALL_PYTHON=true
    INSTALL_GO=true
    INSTALL_CLI_TOOLS=true
    if $ALL_COMPONENTS; then
        INSTALL_RUST=true
        INSTALL_DOCKER_CLI=true
        SETUP_GPG=true
    fi
    if [ -n "$PROFILE_FILE" ]; then
        # shellcheck source=/dev/null
        source "$PROFILE_FILE"
        log_info "Selections loaded from profile: $PROFILE_FILE"
    fi
    # pinentry needs a TTY; never attempt a passphrase-protected key here
    if $GPG_PASSPHRASE_PROTECT; then
        log_warn "GPG passphrase protection needs a TTY - generating without (protect later: gpg --passwd)"
        GPG_PASSPHRASE_PROTECT=false
    fi
else
    echo -e "${YELLOW}Select what to install:${NC}"
    echo ""

    # Languages
    echo -e "${BOLD}Languages & Runtimes:${NC}"
    echo ""

    read -p "   Install Node.js? (nvm + pnpm + bun) [Y/n]: " choice
    [[ "$choice" != "n" && "$choice" != "N" ]] && INSTALL_NODE=true

    read -p "   Install Python? (pyenv + uv) [Y/n]: " choice
    [[ "$choice" != "n" && "$choice" != "N" ]] && INSTALL_PYTHON=true

    read -p "   Install Go? (pinned official release) [Y/n]: " choice
    [[ "$choice" != "n" && "$choice" != "N" ]] && INSTALL_GO=true

    read -p "   Install Rust? (rustup) [y/N]: " choice
    [[ "$choice" == "y" || "$choice" == "Y" ]] && INSTALL_RUST=true

    echo ""
    echo -e "${BOLD}Tools:${NC}"
    echo ""

    read -p "   Install modern CLI tools? (eza, bat, ripgrep, fzf, lazygit, gh, starship) [Y/n]: " choice
    [[ "$choice" != "n" && "$choice" != "N" ]] && INSTALL_CLI_TOOLS=true

    read -p "   Install Docker CLI? (without Docker Desktop) [y/N]: " choice
    [[ "$choice" == "y" || "$choice" == "Y" ]] && INSTALL_DOCKER_CLI=true

    echo ""
    echo -e "${BOLD}Security:${NC}"
    echo ""

    read -p "   Setup GPG for signed commits? [y/N]: " choice
    [[ "$choice" == "y" || "$choice" == "Y" ]] && SETUP_GPG=true

    if $SETUP_GPG; then
        read -p "   Protect GPG key with a passphrase? (recommended) [y/N]: " choice
        [[ "$choice" == "y" || "$choice" == "Y" ]] && GPG_PASSPHRASE_PROTECT=true
    fi
fi

# ===========================================
# Summary
# ===========================================
echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}  Installation Summary${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""
echo -e "   ${BOLD}Always installed:${NC}"
echo "      - Git + configuration"
echo "      - Build essentials"
echo "      - SSH key"
echo ""
echo -e "   ${BOLD}Selected:${NC}"
$INSTALL_NODE && echo "      ✓ Node.js (nvm + pnpm + bun)"
$INSTALL_PYTHON && echo "      ✓ Python (pyenv + uv)"
$INSTALL_GO && echo "      ✓ Go"
$INSTALL_RUST && echo "      ✓ Rust"
$INSTALL_CLI_TOOLS && echo "      ✓ Modern CLI tools"
$INSTALL_DOCKER_CLI && echo "      ✓ Docker CLI"
$SETUP_GPG && echo "      ✓ GPG signing"
echo ""

if ! $NONINTERACTIVE; then
    read -p "Continue with installation? [Y/n]: " confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# ===========================================
# Error Handling
# ===========================================
trap 'log_error "Script failed at line $LINENO"' ERR

# ===========================================
# Architecture (needed by Go AND lazygit; set at top level so it is always
# bound under `set -u`, even when Go is deselected but CLI tools are not)
# ===========================================
case "$(uname -m)" in
  x86_64) GOARCH=amd64; LGARCH=x86_64 ;;
  aarch64|arm64) GOARCH=arm64; LGARCH=arm64 ;;
  *) log_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# ===========================================
# 1. System Update & Base Packages
# ===========================================
log_step "Installing base packages..."

sudo apt -o Acquire::Retries=3 update
sudo apt -o Acquire::Retries=3 upgrade -y

sudo apt -o Acquire::Retries=3 install -y \
    build-essential \
    curl \
    wget \
    unzip \
    zip \
    tar \
    gzip \
    xz-utils \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    pkg-config \
    libssl-dev \
    libffi-dev \
    jq \
    tree \
    htop \
    make \
    cmake

log_success "Base packages installed"

# ===========================================
# 2. Directory Structure
# ===========================================
log_step "Creating project structure..."

mkdir -p ~/projects/{web,python,go,rust,scripts,sandbox}
mkdir -p ~/.local/bin
mkdir -p ~/.config

log_success "Created ~/projects"

# ===========================================
# 3. Git Configuration
# ===========================================
log_step "Configuring Git..."

sudo apt install -y git

# Identity: prompt interactively; non-interactive runs take existing global
# git config, overridable via the GIT_NAME / GIT_EMAIL environment variables.
git_name=$(git config --global user.name 2>/dev/null || true)
git_email=$(git config --global user.email 2>/dev/null || true)
if $NONINTERACTIVE; then
    git_name="${GIT_NAME:-$git_name}"
    git_email="${GIT_EMAIL:-$git_email}"
    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
        log_error "non-interactive mode needs GIT_NAME and GIT_EMAIL env vars (or existing git config)"
        exit 1
    fi
else
    echo ""
    echo -e "${CYAN}Enter your Git details:${NC}"
    read -p "   Full name: " git_name
    read -p "   Email: " git_email
fi

git config --global user.name "$git_name"
git config --global user.email "$git_email"
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global core.eol lf
git config --global core.editor "code --wait"
git config --global pull.rebase false
git config --global push.autoSetupRemote true
git config --global fetch.prune true

# Aliases
git config --global alias.st "status -sb"
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.ci "commit"
git config --global alias.cm "commit -m"
git config --global alias.lg "log --oneline --graph --decorate -20"
git config --global alias.last "log -1 HEAD --stat"
git config --global alias.unstage "reset HEAD --"

log_success "Git configured"

# ===========================================
# Verified installer runner
# ===========================================
# fetch_verified <url> <sha256> <interpreter> [args...]
# Downloads a vendor installer to a temp file, verifies it against the SHA256
# committed IN THIS REPO (audited at pin time - the URL is an immutable
# tag/commit ref), then executes it. A truncated transfer or moved tag can
# never run: checksum mismatch refuses execution and returns nonzero so call
# sites degrade to their log_warn path. Bump a pin by updating the URL ref and
# hash together (sha256sum the fetched script).
fetch_verified() {
    local url="$1" sha="$2" interp="$3" tmp rc
    shift 3
    tmp=$(mktemp) || return 1
    if curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp" "$url" \
       && echo "$sha  $tmp" | sha256sum -c --quiet 2>/dev/null; then
        "$interp" "$tmp" "$@"
        rc=$?
    else
        log_warn "download failed or checksum mismatch: $url"
        rc=1
    fi
    rm -f "$tmp"
    return $rc
}

# latest_github_tag <owner/repo>
# Prints the highest release version (no leading v). Tries the API first,
# honoring GITHUB_TOKEN when present (unauthenticated api.github.com calls
# rate-limit hard on shared CI IPs), then falls back to `git ls-remote`,
# which has no API rate limit at all.
latest_github_tag() {
    local repo="$1" v
    local auth=()
    [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    v=$(curl -fs "${auth[@]}" "https://api.github.com/repos/$repo/releases/latest" \
        | grep -Po '"tag_name": "v?\K[^"]*' || true)
    if [ -z "$v" ]; then
        v=$(git ls-remote --tags "https://github.com/$repo" 2>/dev/null \
            | grep -oP 'refs/tags/v?\K[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true)
    fi
    printf '%s' "$v"
}

# ===========================================
# 4. SSH Key
# ===========================================
log_step "Setting up SSH..."

if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -C "$git_email" -f ~/.ssh/id_ed25519 -N ""
    
    cat > ~/.ssh/config << 'SSH_CONFIG'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
SSH_CONFIG
    chmod 600 ~/.ssh/config
    
    log_success "SSH key generated"
    echo ""
    echo -e "${YELLOW}   ════════════════════════════════════════${NC}"
    echo -e "${YELLOW}   YOUR SSH PUBLIC KEY (add to GitHub):${NC}"
    echo -e "${YELLOW}   ════════════════════════════════════════${NC}"
    echo ""
    cat ~/.ssh/id_ed25519.pub
    echo ""
    pause_enter "   Press Enter after copying..."
else
    log_info "SSH key already exists"
fi

# ===========================================
# 5. Node.js (Optional)
# ===========================================
if $INSTALL_NODE; then
    log_step "Installing Node.js ecosystem..."
    
    # NOTE: Vendor installer scripts (nvm, bun, pyenv, uv, rustup, starship,
    # zoxide) are pinned to immutable tag/commit refs and verified against
    # SHA256 hashes committed in this repo via fetch_verified() - the bytes we
    # audited are the bytes that run. Where an installer itself downloads a
    # payload at runtime (bun, starship, zoxide binaries; rustup toolchains),
    # that payload is the vendor's latest signed release: the installer is
    # pinned, the tool version follows upstream. pnpm and golangci-lint remain
    # transport-hardened only (their URLs embed no immutable ref).
    # NVM
    export NVM_DIR="$HOME/.nvm"
    if [ ! -d "$NVM_DIR" ]; then
        # Tagged ref + checksum committed in this repo: verifies the BYTES we
        # audited, not just that TLS reached github (tags can be force-moved).
        # Downloaded to a file first so a truncated transfer can never execute.
        NVM_INSTALL_SHA256="abdb525ee9f5b48b34d8ed9fc67c6013fb0f659712e401ecd88ab989b3af8f53"
        nvm_tmp=$(mktemp)
        if curl --proto '=https' --tlsv1.2 -fso "$nvm_tmp" \
               "https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh" \
           && echo "$NVM_INSTALL_SHA256  $nvm_tmp" | sha256sum -c --quiet; then
            bash "$nvm_tmp" || log_warn "nvm installer failed - skipping Node.js"
        else
            log_warn "nvm download failed or checksum mismatch - skipping Node.js"
        fi
        rm -f "$nvm_tmp"
    fi
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
        nvm install --lts
        nvm alias default 'lts/*'
        log_success "Node.js $(node --version) installed"
    else
        log_warn "nvm not available - skipping Node.js install"
    fi
    
    # pnpm
    if curl --proto '=https' --tlsv1.2 -fsSL https://get.pnpm.io/install.sh | sh -; then
        export PNPM_HOME="$HOME/.local/share/pnpm"
        export PATH="$PNPM_HOME:$PATH"
        log_success "pnpm installed"
    else
        log_warn "pnpm download failed (network issue?) - install later from https://pnpm.io"
    fi

    # Bun (installer pinned @ bun-v1.3.14; installs the latest bun release)
    if fetch_verified "https://raw.githubusercontent.com/oven-sh/bun/bun-v1.3.14/src/cli/install.sh" \
                      "bab8acfb046aac8c72407bdcce903957665d655d7acaa3e11c7c4616beae68dd" bash; then
        log_success "bun installed"
    else
        log_warn "bun install skipped - install later from https://bun.sh"
    fi

    # Global packages (incl. Claude Code CLI for `claude` in the WSL terminal;
    # the VS Code extension bundles its own copy, this covers terminal use)
    if command -v npm &> /dev/null; then
        if npm install -g typescript ts-node tsx create-vite @anthropic-ai/claude-code; then
            log_success "Node.js ecosystem complete"
        else
            log_warn "some global npm packages failed (network?) - re-run stage2 later"
        fi
    else
        log_warn "npm not available - skipping global npm packages"
    fi
fi

# ===========================================
# 6. Python (Optional)
# ===========================================
if $INSTALL_PYTHON; then
    log_step "Installing Python ecosystem..."
    
    # Dependencies for pyenv
    sudo apt install -y \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libncurses-dev \
        zlib1g-dev \
        liblzma-dev \
        tk-dev \
        libxml2-dev \
        libxmlsec1-dev
    
    # pyenv (installer pinned @ pyenv-installer commit 63a9e6a)
    export PYENV_ROOT="$HOME/.pyenv"
    if [ ! -d "$PYENV_ROOT" ]; then
        fetch_verified "https://raw.githubusercontent.com/pyenv/pyenv-installer/63a9e6a216796aeba2535a3bac8e79ba5d95166d/bin/pyenv-installer" \
                       "4b0adf623a6205727163eb98610b6c5e63f23b99183948b874d867cd9b30ef13" bash \
            || log_warn "pyenv install skipped - Python interpreter not installed"
    fi
    export PATH="$PYENV_ROOT/bin:$PATH"
    if command -v pyenv &> /dev/null; then
        eval "$(pyenv init -)"

        # Install Python - get latest stable 3.12.x
        log_info "Finding latest Python version..."
        PYTHON_VERSION=$(pyenv install --list | grep -E "^\s*3\.12\.[0-9]+$" | tail -1 | tr -d ' ' || true)
        if [ -z "$PYTHON_VERSION" ]; then
            PYTHON_VERSION="3.12.7"  # Fallback
        fi
        log_info "Installing Python $PYTHON_VERSION..."

        if ! pyenv versions | grep -q "$PYTHON_VERSION"; then
            pyenv install "$PYTHON_VERSION" || log_warn "pyenv install $PYTHON_VERSION failed (network?) - re-run stage2 later"
        fi
        if pyenv versions | grep -q "$PYTHON_VERSION"; then
            pyenv global "$PYTHON_VERSION"
            log_success "Python $PYTHON_VERSION installed"
        else
            log_warn "Python $PYTHON_VERSION not installed - skipping pyenv global"
        fi
    else
        log_warn "pyenv not available - skipping Python interpreter install"
    fi

    # uv (versioned installer URL - pins the uv release itself, not just the script)
    if fetch_verified "https://astral.sh/uv/0.11.27/install.sh" \
                      "3f535ec4f066eb95c5056790cc1e06c9487a17f8e1cef202f3d76076b1579769" sh; then
        log_success "uv installed"
    else
        log_warn "uv install skipped - install later from https://astral.sh/uv"
    fi

    # pipx + tools (needs pyenv's pip)
    if command -v pyenv &> /dev/null; then
        pip install --user pipx
        export PATH="$HOME/.local/bin:$PATH"
        pipx install ruff
        pipx install black
        pipx install ipython
    else
        log_warn "pyenv not available - skipping pipx tools (ruff, black, ipython)"
    fi

    log_success "Python ecosystem complete"
fi

# ===========================================
# 7. Go (Optional)
# ===========================================
if $INSTALL_GO; then
    log_step "Installing Go..."

    # Pinned release, verified against checksums committed IN THIS REPO (not
    # fetched from go.dev at runtime - a checksum served by the same origin as
    # the tarball can't detect a compromised origin). Audited at pin time; bump
    # the version and both hashes together (values from go.dev/dl/?mode=json).
    GO_VERSION="go1.26.4"
    GO_SHA256_AMD64="1153d3d50e0ac764b447adfe05c2bcf08e889d42a02e0fe0259bd47f6733ad7f"
    GO_SHA256_ARM64="ef758ae7c6cf9267c9c0ef080b8965f453d89ab2d25d9eb22de4405925238768"

    case "$GOARCH" in
        amd64) GO_SHA256="$GO_SHA256_AMD64" ;;
        arm64) GO_SHA256="$GO_SHA256_ARM64" ;;
    esac
    log_info "Pinned version: $GO_VERSION"

    GO_TARBALL="${GO_VERSION}.linux-${GOARCH}.tar.gz"
    wget -q "https://go.dev/dl/${GO_TARBALL}" -O /tmp/go.tar.gz

    # Integrity failure is a hard stop, never a warning
    echo "$GO_SHA256  /tmp/go.tar.gz" | sha256sum -c --quiet
    log_success "Checksum verified (pinned in-repo)"

    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    
    export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"
    mkdir -p ~/go/{bin,src,pkg}
    
    # Go tools
    /usr/local/go/bin/go install golang.org/x/tools/gopls@latest || log_warn "gopls install failed (network?) - re-run stage2 later"
    /usr/local/go/bin/go install github.com/go-delve/delve/cmd/dlv@latest || log_warn "delve install failed (network?) - re-run stage2 later"

    # golangci-lint: track the LATEST release. golangci-lint is strict about the
    # Go toolchain it was built against - a stale pin fails against a newer Go
    # with "compiled with go1.xx" / analyzer panics - and recent releases work
    # with the pinned Go above. (Bump the Go pin, and latest golangci-lint
    # follows automatically.)
    GOLANGCI_VERSION=$(latest_github_tag golangci/golangci-lint)
    if [ -n "$GOLANGCI_VERSION" ]; then
        curl --proto '=https' --tlsv1.2 -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/v${GOLANGCI_VERSION}/install.sh" \
            | sh -s -- -b "$HOME/go/bin" "v${GOLANGCI_VERSION}"
        log_success "golangci-lint v${GOLANGCI_VERSION} installed"
    else
        log_warn "Could not determine latest golangci-lint version - skipping (install manually later)"
    fi

    log_success "Go $GO_VERSION installed"
fi

# ===========================================
# 8. Rust (Optional)
# ===========================================
if $INSTALL_RUST; then
    log_step "Installing Rust..."
    
    # rustup-init pinned @ 1.29.0; rustup then manages toolchains itself
    if fetch_verified "https://raw.githubusercontent.com/rust-lang/rustup/1.29.0/rustup-init.sh" \
                      "6c30b75a75b28a96fd913a037c8581b580080b6ee9b8169a3c0feb1af7fe8caf" sh -y; then
        source "$HOME/.cargo/env"
        log_success "Rust $(rustc --version | cut -d' ' -f2) installed"
    else
        log_warn "rustup download failed (network issue?) - install later from https://rustup.rs"
    fi
fi

# ===========================================
# 9. Modern CLI Tools (Optional)
# ===========================================
if $INSTALL_CLI_TOOLS; then
    log_step "Installing modern CLI tools..."
    
    # fzf
    if [ ! -d ~/.fzf ]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all --no-bash --no-zsh --no-fish
    fi
    log_success "fzf installed"
    
    # ripgrep
    sudo apt install -y ripgrep
    log_success "ripgrep installed"
    
    # Install shellcheck (linter for shell scripts)
    sudo apt install -y shellcheck
    log_success "shellcheck installed"
    
    # fd
    sudo apt install -y fd-find
    ln -sf "$(command -v fdfind)" ~/.local/bin/fd
    log_success "fd installed"
    
    # bat
    sudo apt install -y bat
    ln -sf "$(command -v batcat)" ~/.local/bin/bat
    log_success "bat installed"
    
    # eza
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt update
    sudo apt install -y eza
    log_success "eza installed"

    # GitHub CLI (gh) - official apt repo (keyrings dir created above)
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt -o Acquire::Retries=3 update
    sudo apt -o Acquire::Retries=3 install -y gh
    log_success "GitHub CLI (gh) installed"
    
    # lazygit (rate-limit-proof tag lookup; not in Ubuntu's apt yet)
    LAZYGIT_VERSION=$(latest_github_tag jesseduffield/lazygit)
    if [ -n "$LAZYGIT_VERSION" ] && \
       curl -fLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_${LGARCH}.tar.gz"; then
        sudo tar xf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit
        rm /tmp/lazygit.tar.gz
        log_success "lazygit installed"
    else
        # GitHub API rate limits are common - don't abort the whole setup over it
        log_warn "lazygit download failed (GitHub API rate limit?) - install later with:"
        log_info "  https://github.com/jesseduffield/lazygit#installation"
    fi
    
    # zoxide
    # zoxide: prefer Ubuntu's signed apt package (24.04+); the vendor script
    # (which resolves "latest" via the rate-limited GitHub API internally) is
    # only a fallback for older releases, pinned @ v0.10.0.
    if sudo apt install -y zoxide 2>/dev/null; then
        log_success "zoxide installed (apt)"
    elif fetch_verified "https://raw.githubusercontent.com/ajeetdsouza/zoxide/v0.10.0/install.sh" \
                        "0c25aed6cce9d56ee0596c9a5df8cbe99ffd0f7a7054de0262234dd268b61404" bash; then
        log_success "zoxide installed (vendor script)"
    else
        log_warn "zoxide install failed - install later from https://github.com/ajeetdsouza/zoxide"
    fi
    
    # Starship
    # starship installer pinned @ v1.26.0
    if fetch_verified "https://raw.githubusercontent.com/starship/starship/v1.26.0/install/install.sh" \
                      "52c64f14a558034ebeb1907ea9364e802b32474576fd3e68265f73bc33cc8fbb" sh -y; then
        log_success "Starship installed"
    else
        log_warn "Starship download failed (network issue?) - install later from https://starship.rs"
    fi

    mkdir -p ~/.config
    cat > ~/.config/starship.toml << 'STARSHIP_CONFIG'
command_timeout = 1000
add_newline = true

format = """
$directory\
$git_branch\
$git_status\
$python\
$nodejs\
$golang\
$rust\
$line_break\
$character"""

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"

[directory]
truncation_length = 3
style = "bold cyan"

[git_branch]
symbol = " "
style = "bold purple"
STARSHIP_CONFIG
fi

# ===========================================
# 10. Docker CLI (Optional)
# ===========================================
if $INSTALL_DOCKER_CLI; then
    log_step "Installing Docker CLI..."
    
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo apt install -y docker-ce-cli docker-compose-plugin
    
    log_success "Docker CLI installed"
    log_warn "Note: Connect to Docker Desktop on Windows or remote daemon"
fi

# ===========================================
# 11. GPG Signing (Optional)
# ===========================================
if $SETUP_GPG; then
    log_step "Setting up GPG..."
    
    # Check for existing GPG key
    existing_key=""
    if gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep -q "sec"; then
        existing_key=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    fi
    
    if [ -z "$existing_key" ]; then
        log_info "Generating new GPG key..."
        if $GPG_PASSPHRASE_PROTECT; then
            # Interactive: gpg-agent prompts for a passphrase (cached after first use)
            log_warn "A passphrase dialog will appear NEXT - have your passphrase ready."
            log_warn "It times out after ~1 minute; type it twice, Tab to <OK>, Enter."
            pause_enter "   Press Enter when ready..."
            # Non-fatal: a timed-out/cancelled dialog must not abort the whole
            # setup (everything after this section would be lost)
            set +e
            gpg --quick-generate-key "$git_name <$git_email>" ed25519 sign 2y
            gpg_status=$?
            set -e
            if [ $gpg_status -ne 0 ]; then
                log_warn "GPG key generation failed or timed out - SKIPPING GPG setup"
                log_info "Everything else will complete. To add GPG later, re-run this script."
                SETUP_GPG=false
            fi
        else
            # Unattended: key stored without a passphrase (convenient, less secure -
            # anyone with access to this WSL user can sign as you)
            cat > /tmp/gpg-key-params << EOF
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Name-Real: $git_name
Name-Email: $git_email
Expire-Date: 2y
%commit
EOF
            gpg --batch --generate-key /tmp/gpg-key-params
            rm /tmp/gpg-key-params
        fi
        
        # Get the new key ID (if generation succeeded)
        if $SETUP_GPG; then
            existing_key=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
        fi
    fi

    if ! $SETUP_GPG; then
        existing_key=""
    fi
    
    if [ -n "$existing_key" ]; then
        git config --global user.signingkey "$existing_key"
        git config --global commit.gpgsign true
        
        log_success "GPG signing enabled (Key: $existing_key)"
        echo ""
        echo -e "${YELLOW}   Your GPG public key (add to GitHub):${NC}"
        echo ""
        gpg --armor --export "$existing_key"
        echo ""
        pause_enter "   Press Enter to continue..."
    else
        log_warn "Could not create GPG key. You can set it up manually later."
    fi
fi

# ===========================================
# 12. Shell Configuration
# ===========================================
log_step "Configuring shell..."

[ -f ~/.bashrc ] && cp ~/.bashrc ~/.bashrc.backup."$(date +%Y%m%d-%H%M%S)"

# Idempotency: if a previous run already wrote our config, strip it and
# rewrite with the CURRENT selections (skipping instead would freeze the
# config to whatever was selected on the first run that reached this point).
# We delete ONLY between our start- and end-markers, so anything you add to
# ~/.bashrc below our block survives a re-run.
start_line=$(grep -n "^# Development Environment Configuration$" ~/.bashrc 2>/dev/null | head -1 | cut -d: -f1 || true)
if [ -n "$start_line" ]; then
    log_info "Existing configuration found - rewriting with current selections"
    end_line=$(grep -n "^# END Development Environment Configuration$" ~/.bashrc 2>/dev/null | head -1 | cut -d: -f1 || true)
    start=$start_line
    prev=$((start_line - 1))
    # Take the divider line above the marker with it, if present
    if [ "$prev" -ge 1 ] && sed -n "${prev}p" ~/.bashrc | grep -q "^# ====="; then
        start=$prev
    fi
    # Reclaim the single blank line our block writes above its divider, so
    # repeated re-runs don't accumulate blank lines above the managed block.
    above=$((start - 1))
    if [ "$above" -ge 1 ] && [ -z "$(sed -n "${above}p" ~/.bashrc)" ]; then
        start=$above
    fi
    if [ -n "$end_line" ] && [ "$end_line" -ge "$start_line" ]; then
        # Bounded delete: our block only, preserving anything the user added below
        sed -i "${start},${end_line}d" ~/.bashrc
    else
        # Legacy block from before end-markers existed - fall back to end-of-file
        sed -i "${start},\$d" ~/.bashrc
    fi
fi

cat >> ~/.bashrc << 'BASHRC_BASE'

# ===========================================
# Development Environment Configuration
# ===========================================

# Path
export PATH="$HOME/.local/bin:$PATH"

# GPG: point pinentry at the current terminal so passphrase prompts work for
# signed commits (without this, gpg fails with "Inappropriate ioctl for device")
export GPG_TTY=$(tty)

# Base aliases
alias ..='cd ..'
alias ...='cd ../..'
alias p='cd ~/projects'
alias projects='cd ~/projects'
alias g='git'
alias gs='git status -sb'
alias gl='git lg'
alias gp='git push'
alias gpl='git pull'
alias reload='source ~/.bashrc'
alias c='clear'

# Functions
mkcd() { mkdir -p "$1" && cd "$1"; }

BASHRC_BASE

# Add Node config if installed
if $INSTALL_NODE; then
cat >> ~/.bashrc << 'NODE_CONFIG'

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Node aliases
alias ni='pnpm install'
alias na='pnpm add'
alias nr='pnpm run'
alias nd='pnpm dev'
alias nb='pnpm build'

# Create React project
newweb() { [ -n "$1" ] && cd ~/projects/web && pnpm create vite "$1" --template react-ts && cd "$1" && pnpm install && code .; }
NODE_CONFIG
fi

# Add Python config if installed
if $INSTALL_PYTHON; then
cat >> ~/.bashrc << 'PYTHON_CONFIG'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &> /dev/null; then
    eval "$(pyenv init -)"
fi

# Python aliases
alias py='python'
alias venv='uv venv && source .venv/bin/activate'
alias activate='source .venv/bin/activate'

# Create Python project
newpy() { [ -n "$1" ] && cd ~/projects/python && mkdir -p "$1" && cd "$1" && uv venv && source .venv/bin/activate && code .; }
PYTHON_CONFIG
fi

# Add Go config if installed
if $INSTALL_GO; then
cat >> ~/.bashrc << 'GO_CONFIG'

# Go
export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"
export GOPATH=$HOME/go

# Create Go project
newgo() { [ -n "$1" ] && cd ~/projects/go && mkdir -p "$1" && cd "$1" && go mod init "$1" && code .; }
GO_CONFIG
fi

# Add Rust config if installed
if $INSTALL_RUST; then
cat >> ~/.bashrc << 'RUST_CONFIG'

# Rust
source "$HOME/.cargo/env"

# Create Rust project
newrust() { [ -n "$1" ] && cd ~/projects/rust && cargo new "$1" && cd "$1" && code .; }
RUST_CONFIG
fi

# Add CLI tools config if installed
if $INSTALL_CLI_TOOLS; then
cat >> ~/.bashrc << 'CLI_CONFIG'

# fzf (keybindings + completion; installer run with --no-bash doesn't touch PATH)
export PATH="$HOME/.fzf/bin:$PATH"
if command -v fzf &> /dev/null; then
    eval "$(fzf --bash)"
fi
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# zoxide
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# Starship
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

# Modern CLI aliases
alias ls='eza --icons'
alias ll='eza -la --icons --git'
alias la='eza -a --icons'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --style=plain'
alias lg='lazygit'
CLI_CONFIG
fi

# Welcome message
cat >> ~/.bashrc << 'WELCOME'

echo ""
echo "Development environment ready!"
echo ""
WELCOME

# End-marker: bounds the managed block so a re-run deletes ONLY our config and
# leaves anything you append below this line untouched. Keep the text in sync
# with the grep in the idempotency section above.
cat >> ~/.bashrc << 'BASHRC_END'

# END Development Environment Configuration
BASHRC_END

log_success "Shell configured"

# ===========================================
# Summary
# ===========================================
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  SETUP COMPLETE!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${CYAN}Installed:${NC}"
echo "   ✓ Git + SSH key"
$INSTALL_NODE && echo "   ✓ Node.js + pnpm + bun"
$INSTALL_PYTHON && echo "   ✓ Python + pyenv + uv"
$INSTALL_GO && echo "   ✓ Go"
$INSTALL_RUST && echo "   ✓ Rust"
$INSTALL_CLI_TOOLS && echo "   ✓ Modern CLI tools"
$INSTALL_DOCKER_CLI && echo "   ✓ Docker CLI"
$SETUP_GPG && echo "   ✓ GPG signing"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo "   1. Run:  source ~/.bashrc   (or close this terminal and open a new one)"
echo "   2. Add SSH key to GitHub: https://github.com/settings/keys"
$SETUP_GPG && echo "   3. Add GPG key to GitHub: https://github.com/settings/gpg/new"
echo "   4. Run stage3-vscode.ps1 in Windows"
echo ""
