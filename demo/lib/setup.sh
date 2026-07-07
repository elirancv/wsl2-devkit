#!/usr/bin/env bash
# Silent environment setup for demo/devkit-demo.tape — sourced by the tape.
# Gives a clean, anonymous prompt, the demo helpers, and a throwaway git repo
# for the real eza/git/lazygit finale. Produces no visible output.
shopt -s expand_aliases 2>/dev/null

# clean prompt: no starship path, no user@host
PROMPT_COMMAND=
PS1=$'\033[36m❯\033[0m '

DEMO_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stage1() { bash "$DEMO_LIB/stage1.sh"; }
stage2() { bash "$DEMO_LIB/stage2.sh"; }

# finale aliases — real tools, but --no-user/--no-time so no username leaks
alias ll='eza -la --icons --git --no-user --no-time'
alias lt='eza --tree --level=2 --icons'
alias gl='git log --oneline --graph --decorate -20'
# isolated lazygit config so the finale skips the first-run welcome popup
printf 'disableStartupPopups: true\ngui:\n  showRandomTip: false\n  nerdFontsVersion: "3"\n' > /tmp/lg-demo.yml
alias lg='lazygit --use-config-file=/tmp/lg-demo.yml'

# throwaway repo (generic author) for the finale
rm -rf /tmp/my-app && mkdir -p /tmp/my-app/src
cd /tmp/my-app || return
git init -q
git config user.name  dev
git config user.email dev@local
git config commit.gpgsign false   # never touch your real GPG key in the demo
git config tag.gpgsign    false
printf 'export const answer = () => 42\n'                 > src/index.ts
printf '# my-app\n\nBootstrapped with wsl2-devkit.\n'     > README.md
printf '.env\nnode_modules/\n'                            > .gitignore
git add README.md src   && git commit -qm 'init: scaffold app'   >/dev/null 2>&1
git add .gitignore      && git commit -qm 'chore: add .gitignore' >/dev/null 2>&1
