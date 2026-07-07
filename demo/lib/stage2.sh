#!/usr/bin/env bash
# Illustrative reproduction of wsl/stage2-ubuntu.sh's interactive menu + install
# log, for the VHS demo. The prompts use real `read`, so VHS drives them live.
set -u

G=$'\033[1;32m'; GR=$'\033[0;90m'; C=$'\033[1;36m'; N=$'\033[0m'
ask()  { printf '   %s' "$1"; read -r _; }
info() { printf '%b\n' "${GR}   $1${N}"; sleep 0.14; }
ok()   { printf '%b\n' "${G}   [OK]${N} $1"; sleep 0.14; }

printf '%b\n\n' "${C}>> Stage 2 · Ubuntu dev toolchain${N}"
echo "Select what to install:"
echo
echo "Languages & Runtimes:"
ask "Install Node.js? (nvm + pnpm + bun) [Y/n]: "
ask "Install Python? (pyenv + uv) [Y/n]: "
ask "Install Go? (latest official) [Y/n]: "
ask "Install Rust? (rustup) [y/N]: "
echo
echo "Tools:"
ask "Install modern CLI tools? (eza, bat, ripgrep, fzf, lazygit, gh, starship) [Y/n]: "
ask "Install Docker CLI? (without Docker Desktop) [y/N]: "
echo
echo "Security:"
ask "Setup GPG for signed commits? [y/N]: "

printf '\n%b\n\n' "${C}>> Installing${N}"
info "apt: build-essential · git · jq · htop · tree"
ok   "base system"
info "nvm → Node LTS → pnpm + bun"
ok   "Node.js"
info "pyenv → Python 3.12 → uv + ruff"
ok   "Python"
info "Go (official) + gopls + delve"
ok   "Go"
info "eza · bat · ripgrep · fd · fzf · lazygit · zoxide · starship · gh · shellcheck"
ok   "modern CLI"
info "Ed25519 SSH key + GPG signing key"
ok   "security"
# shellcheck disable=SC2088  # literal "~" is intentional display text, not a path
info "~/projects/{web,python,go,rust,scripts,sandbox}"
ok   "project structure"
printf '\n%b\n' "${G}   ✓ Environment ready — run  verify-setup.sh  to confirm${N}"
sleep 0.5
