#!/usr/bin/env bash
# ===========================================================================
# verify-setup.sh - Health check for the WSL2 dev environment (Stage 2 + 3)
# ---------------------------------------------------------------------------
# Confirms what stage2-ubuntu.sh + stage3-vscode.ps1 were supposed to install
# actually landed and works. Read-only: it changes nothing. Safe to re-run.
#
#   bash verify-setup.sh            # full report
#   bash verify-setup.sh -q         # quiet: only show problems + summary
#
# Exit code: 0 if all REQUIRED checks pass, 1 otherwise. Optional-toolchain
# misses (Node/Python/Go/Rust) are reported as warnings - they only matter if
# you chose that language during setup.
# ===========================================================================

# Labels below intentionally print a literal "~/..." for readability; the actual
# filesystem tests all use $HOME. Silence the tilde-in-quotes lint file-wide.
# shellcheck disable=SC2088
set -uo pipefail

QUIET=false
[[ "${1:-}" == "-q" || "${1:-}" == "--quiet" ]] && QUIET=true

# --- Make the check see tools exactly where stage2-ubuntu.sh puts them, ------
# --- since a non-interactive shell won't have sourced ~/.bashrc. ------------
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/go/bin:$HOME/go/bin:$HOME/.fzf/bin:$PATH"
export NVM_DIR="$HOME/.nvm";        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
export PYENV_ROOT="$HOME/.pyenv";   [ -d "$PYENV_ROOT/bin" ] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init - bash 2>/dev/null)" 2>/dev/null || true
export PNPM_HOME="$HOME/.local/share/pnpm"; export PATH="$PNPM_HOME:$PNPM_HOME/bin:$PATH"
export BUN_INSTALL="$HOME/.bun";    export PATH="$BUN_INSTALL/bin:$PATH"

# --- Colors -----------------------------------------------------------------
if [ -t 1 ]; then
  G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'
else
  G=""; R=""; Y=""; C=""; B=""; N=""
fi

PASS=0; FAIL=0; WARN=0

section() { $QUIET && return; printf "\n${C}${B}%s${N}\n" "== $1 =="; }

# ok  <label> [version-string]
ok()   { PASS=$((PASS+1)); $QUIET && return; printf "  ${G}[OK]${N}   %-22s %s\n" "$1" "${2:-}"; }
# bad <label> <hint>   (required -> counts as failure)
bad()  { FAIL=$((FAIL+1));            printf "  ${R}[MISS]${N} %-22s ${R}%s${N}\n" "$1" "${2:-}"; }
# opt <label> <hint>   (optional -> warning only)
opt()  { WARN=$((WARN+1));            printf "  ${Y}[warn]${N} %-22s ${Y}%s${N}\n" "$1" "${2:-}"; }

# check_req <label> <cmd> [alt-cmd]   required tool
check_req() {
  local label="$1" c1="$2" c2="${3:-}"
  if command -v "$c1" >/dev/null 2>&1; then ok "$label" "$(command -v "$c1")"
  elif [ -n "$c2" ] && command -v "$c2" >/dev/null 2>&1; then ok "$label" "$(command -v "$c2")"
  else bad "$label" "not found on PATH"; fi
}

# check_opt <label> <cmd> [alt-cmd]   optional toolchain tool
check_opt() {
  local label="$1" c1="$2" c2="${3:-}"
  if command -v "$c1" >/dev/null 2>&1; then ok "$label" "$(command -v "$c1")"
  elif [ -n "$c2" ] && command -v "$c2" >/dev/null 2>&1; then ok "$label" "$(command -v "$c2")"
  else opt "$label" "missing (only needed if you selected it)"; fi
}

printf "${B}WSL Dev Environment - Health Check${N}\n"
printf "user=%s  distro=%s  $(date '+%Y-%m-%d %H:%M')\n" "$(whoami)" "${WSL_DISTRO_NAME:-?}"

# ---------------------------------------------------------------------------
section "Base toolchain (always installed)"
check_req "git"        git
check_req "curl"       curl
check_req "wget"       wget
check_req "jq"         jq
check_req "make"       make
check_req "gcc"        gcc
check_req "cmake"      cmake
check_req "gnupg"      gpg

# ---------------------------------------------------------------------------
# Modern CLI tools are gated behind the "Install modern CLI tools?" prompt in
# stage2-ubuntu.sh, so a machine that declined them is still healthy -> warn.
section "Modern CLI tools (optional)"
check_opt "shellcheck" shellcheck
check_opt "ripgrep"    rg
check_opt "fd"         fd fdfind
check_opt "bat"        bat batcat
check_opt "eza"        eza
check_opt "fzf"        fzf
check_opt "zoxide"     zoxide
check_opt "starship"   starship
check_opt "lazygit"    lazygit
check_opt "gh"         gh

# ---------------------------------------------------------------------------
section "Node.js (optional)"
check_opt "nvm"  nvm       # a function, defined via sourced nvm.sh above
check_opt "node" node
check_opt "npm"  npm
check_opt "pnpm" pnpm
check_opt "bun"  bun

# ---------------------------------------------------------------------------
section "Python (optional)"
check_opt "pyenv"  pyenv
check_opt "python" python python3
check_opt "uv"     uv
check_opt "pipx"   pipx

# ---------------------------------------------------------------------------
section "Go (optional)"
check_opt "go"            go
check_opt "golangci-lint" golangci-lint

# ---------------------------------------------------------------------------
section "Rust (optional)"
check_opt "rustc"  rustc
check_opt "cargo"  cargo
check_opt "rustup" rustup

# ---------------------------------------------------------------------------
section "Shell configuration (~/.bashrc managed block)"
if grep -q '^# Development Environment Configuration$' ~/.bashrc 2>/dev/null; then
  ok "start marker"
else
  bad "start marker" "managed .bashrc block missing - re-run stage2-ubuntu.sh"
fi
if grep -q '^# END Development Environment Configuration$' ~/.bashrc 2>/dev/null; then
  ok "end marker"
else
  opt "end marker" "older block without end-marker (cosmetic)"
fi
# Each helper is written only when its language was selected. Detect that
# selection by the tool the helper actually invokes (pnpm/uv/go/cargo) - NOT by
# python/node generally, since stock Ubuntu ships python3 and CI images ship
# node, neither of which means stage2's Python/Node setup ever ran.
for fn in newweb newpy newgo newrust; do
  case "$fn" in
    newweb)  rt=pnpm ;;
    newpy)   rt=uv ;;
    newgo)   rt=go ;;
    newrust) rt=cargo ;;
  esac
  if grep -qE "^\s*${fn}\(\)" ~/.bashrc 2>/dev/null; then
    ok "helper: $fn"
  elif command -v "$rt" >/dev/null 2>&1; then
    bad "helper: $fn" "missing though $rt is installed - re-run stage2-ubuntu.sh"
  else
    opt "helper: $fn" "language not selected"
  fi
done

# ---------------------------------------------------------------------------
section "Project directories"
for d in web python go rust scripts sandbox; do
  if [ -d "$HOME/projects/$d" ]; then ok "~/projects/$d"; else bad "~/projects/$d" "missing"; fi
done
[ -d "$HOME/go/bin" ] && ok "~/go/bin" || opt "~/go/bin" "missing (created on first Go use)"

# ---------------------------------------------------------------------------
section "Git / SSH / GitHub"
gname=$(git config --global user.name  2>/dev/null || true)
gmail=$(git config --global user.email 2>/dev/null || true)
[ -n "$gname" ] && ok "git user.name"  "$gname" || bad "git user.name"  "unset"
[ -n "$gmail" ] && ok "git user.email" "$gmail" || bad "git user.email" "unset"
[ "$(git config --global init.defaultBranch 2>/dev/null)" = "main" ] && ok "init.defaultBranch" "main" || opt "init.defaultBranch" "not 'main'"
if [ -f "$HOME/.ssh/id_ed25519" ] && [ -f "$HOME/.ssh/id_ed25519.pub" ]; then ok "SSH key" "ed25519"; else bad "SSH key" "~/.ssh/id_ed25519 missing"; fi
if command -v ssh >/dev/null 2>&1; then
  # Capture first, then grep: `ssh -T git@github.com` always exits 1 (GitHub
  # grants no shell), which under `set -o pipefail` would make a piped `if`
  # condition false even on success. So test the captured text instead.
  ssh_out=$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -o BatchMode=yes -T git@github.com 2>&1 || true)
  if printf '%s' "$ssh_out" | grep -qi "successfully authenticated"; then
    ok "GitHub SSH auth" "works"
  else
    opt "GitHub SSH auth" "key not accepted by GitHub (add ~/.ssh/id_ed25519.pub)"
  fi
fi
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "gh auth" "logged in"; else opt "gh auth" "run: gh auth login"; fi
fi

# ---------------------------------------------------------------------------
section "VS Code (WSL remote extensions)"
CS=$(ls -t "$HOME"/.vscode-server/bin/*/bin/code-server 2>/dev/null | head -1 || true)
if [ -n "$CS" ]; then
  n=$(env -u VSCODE_IPC_HOOK_CLI "$CS" --list-extensions 2>/dev/null | grep -c . || echo 0)
  if [ "$n" -ge 10 ]; then ok "WSL extensions" "$n installed"; else opt "WSL extensions" "only $n - open a WSL folder & re-run stage3-vscode.ps1"; fi
else
  opt "WSL server" "not provisioned yet (open a WSL folder in VS Code once)"
fi

# ---------------------------------------------------------------------------
printf "\n${B}Summary:${N} ${G}%d passed${N}, ${Y}%d warnings${N}, ${R}%d missing (required)${N}\n" "$PASS" "$WARN" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf "${G}${B}Machine looks healthy.${N} Warnings are optional/informational.\n"
  exit 0
else
  printf "${R}${B}%d required item(s) missing.${N} Re-run the relevant setup stage to fix.\n" "$FAIL"
  exit 1
fi
