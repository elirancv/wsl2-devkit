# wsl2-devkit — Overview

What this project is, who it's for, and which of its claims you can verify yourself.

**Links:** [Latest release](https://github.com/elirancv/wsl2-devkit/releases/latest) · [Full reference](DOCUMENTATION.md) · [Changelog](../CHANGELOG.md)

---

## In one sentence

> Turn a Windows PC into a professional Linux dev machine in about 30 minutes — with all of development **isolated in WSL2**, so Windows stays clean and fast no matter what you build, install, or experiment with.

## Why isolation is the point

- **Experiment freely** — languages, tools, and config live inside the Linux environment, which you can rebuild from scratch in minutes whenever you choose. Windows never notices.
- **Windows stays fast and clean** — no runtimes, PATH clutter, or daemons on the host. Editors, browsers, and fonts stay native; code runs where the filesystem is fast.
- **Reversible by design** — built-in backup (rotated), validated restore, and a health check that tells you precisely what state you're in.
- **One machine, both worlds** — full Linux tooling and native Windows apps, no dual-boot, no VM window.

The kit enforces this separation by design — not by hope.

## New to WSL2?

Developing on Windows used to mean choosing between two compromises: install every runtime directly on Windows and watch it slow down under the clutter, or run Linux in a virtual machine and fight the sluggish filesystem and clunky window.

**WSL2** (Windows Subsystem for Linux) removed that trade-off — Windows runs a real Linux system *inside* itself, at native speed, no dual-boot, no second computer. It's how a huge share of professional developers on Windows actually work: Windows for the browser and editor, Linux for the code.

The remaining catch: setting it up *well* — the languages, the tooling, the SSH keys, the terminal that doesn't look like 1995 — takes an evening of googling and a dozen chances to get something wrong.

**wsl2-devkit is that evening, scripted.** Four steps you run in order. It asks what you want (Node? Python? Go? Rust?), installs it the right way, and finishes with a **52-point health check** that proves everything works. It even comes with an undo button: built-in backup, restore, and reset tools.

## For engineers

Think of it as **workstation-as-code for the individual engineer** — the rigor fleet tooling applies to server farms (pinning, CI gates, provable idempotency), applied to one bare-metal laptop:

- **Four ordered stages** — winget apps → WSL2 + auto-sized `.wslconfig` → dev toolchain (nvm/pnpm/bun, pyenv/uv, pinned Go, rustup, modern CLI: eza · bat · ripgrep · fzf · zoxide · starship · lazygit · gh) → VS Code extensions installed *into the WSL server*, not inertly on Windows.
- **Supply chain you can audit** — every vendor installer script is fetched from an **immutable tag/commit ref and verified against a SHA256 committed in the repo** before a byte executes. The Go tarball is version-pinned + checksummed. Releases ship `checksums.txt`.
- **CI that tests the kit, not just the syntax** — every push runs the real installer **twice** on a clean runner and asserts the managed `~/.bashrc` block is *byte-identical* after the re-run, then passes the 52-check verifier. ShellCheck, PSScriptAnalyzer, and a genuine Windows PowerShell 5.1 parse job gate every PR.
- **Unattended mode** — `--yes` / `--all` / `--profile file.conf` for golden images and repeatable rebuilds.
- **Day-2 tooling** — health verifier, distro backup with rotation, validated restore, VHD compaction, typed-confirmation reset.
- **No telemetry. Keys generated locally. MIT.**

## Verify the claims yourself

Don't take the bullets above on faith — each maps to something checkable:

| Claim | Where to check |
|---|---|
| ~30 minutes, fresh PC → verified dev machine | Stage timings in the README |
| 52-check health verifier | `wsl/verify-setup.sh`, run on every CI push |
| 8/8 vendor installers pinned + checksum-verified in-repo | `fetch_verified()` in `wsl/stage2-ubuntu.sh` |
| Idempotency is CI-enforced, not claimed | Twice-run byte-identical assert in `.github/workflows/ci.yml` |
| Every release ships script checksums | `checksums.txt` on each release |

## See it

- Terminal walkthrough: [`demo/devkit-demo.gif`](../demo/devkit-demo.gif) — reproducible via `make demo`
- Architecture and flow diagrams: [README → How it works](../README.md#how-it-works)

## From A to Z — the whole setup, honestly

What a brand-new user actually does, starting from nothing but Windows:

1. **Check you qualify** — Windows 10 (build 19041+) or Windows 11, virtualization enabled in BIOS/UEFI (usually already is).
1. **Get the code** (PowerShell):

   ```powershell
   git clone https://github.com/elirancv/wsl2-devkit
   cd wsl2-devkit
   # no git yet? Download ZIP works too - then run:  Get-ChildItem -Recurse *.ps1 | Unblock-File
   ```

1. **Stage 0 — Windows apps** *(optional)*: browser, VS Code, Windows Terminal, Git, the Nerd Font that makes terminal icons render.

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\windows\stage0-winget.ps1
   ```

1. **Stage 1 — turn on WSL2 + install Ubuntu** (as Administrator):

   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\windows\stage1-windows.ps1
   ```

   It asks for **one reboot**, then you run it once more — Ubuntu installs on the second pass. Open Ubuntu from the Start menu and pick a username + password.

1. **Stage 2 — the dev toolchain** (inside the new Ubuntu terminal):

   ```bash
   git clone https://github.com/elirancv/wsl2-devkit && cd wsl2-devkit
   ./wsl/stage2-ubuntu.sh        # interactive menu - or --yes for the defaults
   exec $SHELL -l
   ```

1. **Stage 3 — VS Code wiring** (back in PowerShell): `.\windows\stage3-vscode.ps1`
1. **Z — prove it worked**:

   ```bash
   make verify        # 52 checks; green = you're a Linux developer now
   ```

Total: ~30 minutes, one reboot, and every step is safe to re-run if anything hiccups.

## FAQ

**How is this different from dotfiles?** Dotfiles personalize an environment that already works — prompts, aliases, editor settings. wsl2-devkit builds the environment underneath: OS features, `.wslconfig` sizing, language toolchains, keys, and the host↔WSL editor bridge. Your dotfiles layer on top nicely.

**Is it safe to run scripts like this?** Read them first — that's the intended workflow. They're plain PowerShell/bash, MIT-licensed, no telemetry, and each release publishes SHA256 checksums so you can audit a tag and run exactly those bytes.

**I already have WSL2.** Stage 2 alone still gets you the toolchain + shell setup, and `verify-setup.sh` will tell you what's missing. Everything is safe to re-run.

**Why not Dev Containers / Ansible?** Different job. This is a *personal machine* bootstrap optimized for native speed and a clean host — not fleet configuration management. The scaffolding it installs works fine with containers on top.

## About

**wsl2-devkit** is MIT-licensed and built by [Eliran Cohen](https://github.com/elirancv). Contributions welcome — see [CONTRIBUTING.md](../CONTRIBUTING.md); security reports go through [private disclosure](../SECURITY.md).
