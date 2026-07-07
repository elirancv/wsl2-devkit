# wsl2-devkit — Press Kit

Everything you need to write or talk about wsl2-devkit. Quote freely; it's MIT.

**Links:** [Repository](https://github.com/elirancv/wsl2-devkit) · [Latest release](https://github.com/elirancv/wsl2-devkit/releases/latest) · [Full documentation](DOCUMENTATION.md)

---

## One-liner

> Turn a fresh Windows PC into a professional Linux dev machine in about 30 minutes — and keep Windows clean while doing it.

## The pitch — for people who've never heard of WSL2

Windows can run a real Linux system *inside* itself — no dual-boot, no slow virtual machine window, no second computer. Microsoft calls it **WSL2** (Windows Subsystem for Linux), and it's how a huge share of professional developers on Windows actually work: Windows for the browser and editor, Linux for the code.

The catch: setting it up *well* — the languages, the tooling, the SSH keys, the terminal that doesn't look like 1995 — takes an evening of googling and a dozen chances to get something wrong.

**wsl2-devkit is that evening, scripted.** Four steps you run in order. It asks what you want (Node? Python? Go? Rust?), installs it the right way, and finishes with a **52-point health check** that proves everything works. It even comes with an undo button: built-in backup, restore, and reset tools.

## The pitch — for engineers

wsl2-devkit is a staged, **idempotency-proven** provisioning kit for Windows 10/11 + WSL2 Ubuntu:

- **Four ordered stages** — winget apps → WSL2 + auto-sized `.wslconfig` → dev toolchain (nvm/pnpm/bun, pyenv/uv, pinned Go, rustup, modern CLI: eza · bat · ripgrep · fzf · zoxide · starship · lazygit · gh) → VS Code extensions installed *into the WSL server*, not inertly on Windows.
- **Supply chain you can audit** — every vendor installer script is fetched from an **immutable tag/commit ref and verified against a SHA256 committed in the repo** before a byte executes. The Go tarball is version-pinned + checksummed. Releases ship `checksums.txt`.
- **CI that tests the kit, not just the syntax** — every push runs the real installer **twice** on a clean runner and asserts the managed `~/.bashrc` block is *byte-identical* after the re-run, then passes the 52-check verifier. ShellCheck, PSScriptAnalyzer, and a genuine Windows PowerShell 5.1 parse job gate every PR.
- **Unattended mode** — `--yes` / `--all` / `--profile file.conf` for golden images and repeatable rebuilds.
- **Day-2 tooling** — health verifier, distro backup with rotation, validated restore, VHD compaction, typed-confirmation reset.
- **No telemetry. Keys generated locally. MIT.**

## Design principle

**Windows stays clean.** Editors, browsers, and fonts live on Windows; every language runtime, linter, and CLI tool lives in WSL2, where the filesystem is fast. The kit enforces the separation instead of hoping you maintain it.

## Numbers that are true

| Claim | Backing |
|---|---|
| ~30 minutes, fresh PC → verified dev machine | Stage timings in the README |
| 52-check health verifier | `wsl/verify-setup.sh`, run on every CI push |
| 8/8 vendor installers pinned + checksum-verified in-repo | `fetch_verified()` in `wsl/stage2-ubuntu.sh` |
| Idempotency is CI-enforced, not claimed | Twice-run byte-identical assert in `.github/workflows/ci.yml` |
| Every release ships script checksums | `checksums.txt` on each release |

## Assets

- **Hero GIF** (terminal walkthrough, 1200×750): [`demo/devkit-demo.gif`](../demo/devkit-demo.gif) — reproducible via `make demo`, fully anonymized
- Architecture + flow diagrams: rendered Mermaid in the [README](../README.md#how-it-works)
- Suggested screenshot: the verifier's green `52 passed, 0 warnings, 0 missing` summary

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

## FAQ ammunition

**Is it safe to run scripts like this?** Read them first — that's the intended workflow. They're plain PowerShell/bash, MIT-licensed, no telemetry, and each release publishes SHA256 checksums so you can audit a tag and run exactly those bytes.

**I already have WSL2.** Stage 2 alone still gets you the toolchain + shell setup, and `verify-setup.sh` will tell you what's missing. Everything is safe to re-run.

**Why not Dev Containers / Ansible?** Different job. This is a *personal machine* bootstrap optimized for native speed and a clean host — not fleet configuration management. The scaffolding it installs works fine with containers on top.

## Boilerplate

> **wsl2-devkit** is an open-source (MIT) provisioning kit that turns a fresh Windows 10/11 machine into a complete, verified Linux development environment using WSL2 — in four staged scripts and about 30 minutes. Built by [Eliran Cohen](https://github.com/elirancv).
