#!/usr/bin/env bash
# Illustrative reproduction of windows/stage1-windows.ps1's output, for the
# VHS demo. The real Stage 1 runs in Admin PowerShell on the Windows host.
set -u

G=$'\033[1;32m'; GR=$'\033[0;90m'; C=$'\033[1;36m'; Y=$'\033[1;33m'; N=$'\033[0m'
line() { printf '%b\n' "$1"; sleep "${2:-0.18}"; }

printf '%b\n\n' "${C}>> Stage 1 · WSL2 + Ubuntu   ${GR}(Windows host — Admin PowerShell)${N}"

line "${GR}   Pre-flight checks${N}" 0.25
line "${G}   [OK]${N} Windows 11  ·  Build 22631        ${GR}(≥ 19041)${N}"
line "${G}   [OK]${N} Virtualization enabled in firmware"
line "${G}   [OK]${N} 16 GB RAM detected"
line "${G}   [OK]${N} 512 GB free on C:"

printf '\n%b\n' "${GR}   Sizing WSL to your machine and writing .wslconfig …${N}"
sleep 0.35
printf '%b\n' "${Y}"
cat <<'CFG'
      [wsl2]
      memory=6GB               # ~half of 16 GB
      processors=4             # half your cores
      swap=4GB
      networkingMode=mirrored
      [experimental]
      autoMemoryReclaim=gradual
      sparseVhd=true
CFG
printf '%b' "${N}"
sleep 0.4

line "\n${G}   [OK]${N} WSL2 features enabled"
line "${G}   [OK]${N} Ubuntu installed"
printf '\n%b\n' "${C}   → Reboot, create your Ubuntu user, then run Stage 2${N}"
sleep 0.5
