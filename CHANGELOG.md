# Changelog

All notable changes to wsl2-devkit are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [5.3.0] - 2026-07-07

### Added
- **Banners show the live release version**: every stage script and wsl-tools
  resolves `git describe --tags` at runtime — `v5.3.0` at a release tag,
  `v5.3.0-N-gsha` when ahead of it, silent for ZIP copies without `.git`.
  Replaces the drift-prone hardcoded numbers for good. (#9, #10)
- `make checksums` writes the `checksums.txt` release artifact, and
  CONTRIBUTING gains a **Releasing** section documenting the full tag +
  release procedure. (#8)

### Fixed
- The version probe no longer leaks git's exit code (128 in tagless/shallow
  checkouts) as the script's own exit code. (#10)

### Docs
- README + Troubleshooting now cover the "not digitally signed" trap:
  `Unblock-File` for ZIP downloads, the `\\wsl.localhost` UNC rule, and the
  separate Windows PowerShell 5.1 vs pwsh execution policies. (#9)

## [5.2.0] - 2026-07-07

### Added
- `make bump-go` — one-command update of the pinned Go version + in-repo
  checksums (fetches release metadata, rewrites the pin, prints the diff). (#1)
- Dependabot keeps the SHA-pinned GitHub Actions current via weekly PRs. (#3)

### Fixed
- CI smoke no longer stalls on the runner image's snap-backed firefox during
  `apt upgrade` — the packages are held before provisioning. (#5)
- GitHub tag lookups (golangci-lint, lazygit) are rate-limit-proof: they honor
  `GITHUB_TOKEN` when present and fall back to `git ls-remote`, which has no
  API rate limit. Previously they failed silently on shared CI runner IPs and
  rate-limited networks. (#6)
- zoxide installs from Ubuntu 24.04's signed apt repo, keeping the pinned
  vendor script (whose internal "latest" lookup hits the rate-limited API)
  only as a fallback for older releases. (#6)

## [5.1.0] - 2026-07-07

### Changed
- **All remaining vendor installer scripts are now pinned and verified**: pyenv,
  uv, bun, rustup, starship, and zoxide join Go and nvm — each fetched from an
  immutable tag/commit ref, downloaded to a file, and checked against a SHA256
  committed in this repo via a shared `fetch_verified()` helper before
  execution. The uv pin uses Astral's versioned installer URL, pinning the uv
  release itself. Payloads that installers fetch at runtime (bun, starship,
  zoxide binaries; rustup toolchains) remain the vendor's latest signed release.
- CI actions are pinned by commit SHA instead of mutable tags.

### Added
- `windows-latest` CI job: parses every PowerShell script with the Windows
  PowerShell 5.1 engine (the one user machines actually run, vs. pwsh core in
  the lint job) and exercises `wsl-tools.ps1`'s non-mutating help path.

## [5.0.0] - 2026-07-07

### Added
- **Non-interactive mode** for `stage2-ubuntu.sh`: `--yes` (menu defaults),
  `--all` (everything), `--profile FILE` (defaults + sourced overrides), with
  git identity from existing config or `GIT_NAME`/`GIT_EMAIL` env vars.
- **CI on every push** (GitHub Actions): ShellCheck + `bash -n` on all shell
  scripts, PSScriptAnalyzer on all PowerShell scripts, and an end-to-end smoke
  test that runs the real Stage 2 **twice** on a clean Ubuntu runner, asserts
  the managed `~/.bashrc` block is byte-identical after the re-run, and passes
  the 52-check health verifier.
- Tagged releases with published script checksums.

### Changed
- **Go is now version-pinned and verified against a SHA256 committed in this
  repo** — previously the checksum was fetched at runtime from go.dev, the same
  origin as the tarball, which cannot detect a compromised origin.
- **The nvm installer is checksum-verified in-repo** against its tagged ref and
  downloaded to a file before execution (a truncated transfer can never run).

### Fixed
- `verify-setup.sh` detects language selection by the tool each `newX` helper
  actually invokes (`pnpm`/`uv`/`go`/`cargo`) — keying on `python3`/`node`
  falsely demanded helpers on systems where those ship preinstalled.

## [4.5] - 2026-07-07

### Changed
- Restructured into the **wsl2-devkit** project layout: Windows-side scripts in
  `windows/`, WSL-side scripts in `wsl/`, reference guide in `docs/`.
- Renamed scripts to reflect run order: `stage0-winget.ps1`, `stage1-windows.ps1`,
  `stage2-ubuntu.sh`, `stage3-vscode.ps1` (maintenance/health-check scripts keep
  their descriptive names). All cross-references updated.

### Added
- `Makefile` with `verify` / `lint` / `demo` / `help` targets (run inside WSL).
- VHS demo (`demo/devkit-demo.tape`) rendering the animated README walkthrough
  GIF via `make demo`.
- Project scaffolding: overhauled `README.md` (incl. a **Security & trust**
  section), `LICENSE` (MIT), `.gitignore`, `.editorconfig`, and this `CHANGELOG.md`.

### Fixed
- `verify-setup.sh` no longer reports required failures for optional CLI tools
  or `newX` helpers you didn't select — those are now warnings, and a helper is
  only flagged as missing when its language toolchain is actually installed.
- `stage2-ubuntu.sh` no longer accumulates blank lines above the managed
  `~/.bashrc` block on repeated runs.
- A flaky network during `go install`, global `npm install`, or `pyenv install`
  now degrades to a warning instead of aborting the run before shell config.

### Removed
- Development artifacts: `logs/` and `Install-Notes.txt`.

## [4.4] - 2026-07-07

### Added
- `verify-setup.sh` — read-only health check for the WSL dev environment
  (base CLI, optional Node/Python/Go/Rust toolchains, the managed `.bashrc`
  block + `newX` helpers, project directories, git/SSH/GitHub auth, and the WSL
  VS Code extension count). Exits non-zero if any required item is missing.

### Changed
- **stage3-vscode.ps1**: installs extensions where they actually run — only UI
  extensions (themes + Remote-* clients) on Windows, all workspace extensions
  (language servers, linters, formatters, debuggers) into the WSL server via
  headless `code-server --install-extension`. Previously everything installed on
  Windows behind a false "Remote-WSL auto-syncs them" claim, leaving the WSL side
  empty. Honest two-run message when the WSL server isn't provisioned yet.
- Removed the deprecated `ruff.lint.run` setting that forced Ruff onto the legacy
  `ruff-lsp` server instead of the native (Rust) server.

### Fixed (hardening pass — correctness review of the not-yet-run scripts)
- **wsl-tools.ps1**: backup deletes a partial/corrupt `.tar` on failed export;
  restore validates archive size before unregistering (never wipes the live
  distro for a bad backup); reset verifies the distro is in the online catalog
  before unregistering (never leaves the machine distro-less); clean compacts the
  *default* distro's VHD; removed the global `OutputEncoding = Unicode` that
  garbled UTF-8 passthrough from `wsl -- ...`.
- **stage0-winget.ps1**: probes `winget --version` and gates
  `--disable-interactivity` on winget ≥ 1.4 (old/stub winget on debloated Win10
  images no longer makes every install silently fail); benign exit codes
  (already-installed, no-op upgrade, reboot-required) no longer reported as
  failures.
- **stage1-windows.ps1**: strips the UTF-16 BOM from `wsl --list` output so the
  "Ubuntu already installed" check works on the second run.
- **stage2-ubuntu.sh**: Docker keyring `gpg --dearmor --yes` (idempotent re-run);
  nvm/pnpm/bun/pyenv/uv/rustup/zoxide/starship installers warn-and-continue
  instead of aborting the whole run on a transient download failure.

## [4.3]

### Added
- Full Rust support: `~/projects/rust`, `newrust` helper (`cargo new`), VS Code
  Rust extensions (rust-analyzer + CodeLLDB + Even Better TOML), `[rust]` editor
  settings with clippy on save, `target/` in the `.gitignore` template, `*.rs` in
  `.editorconfig`, and cargo cache clearing in `wsl-tools.ps1 clean`.

## [4.2]

### Fixed
- Ubuntu detection in Stage 1 (UTF-16 output of `wsl --list` on PowerShell 5.1).
- `.wslconfig` written without a BOM (parser compatibility).
- Mirrored networking / dnsTunneling / autoProxy only applied on Windows 11 22H2+.
- Stage 1 no longer runs WSL commands before the required restart (run twice).
- Ubuntu 24.04 compatibility: `libncurses-dev` replaces removed `libncurses5-dev`.
- lazygit download failure (GitHub rate limit) no longer aborts setup.
- fzf keybindings load correctly (`eval "$(fzf --bash)"` + PATH fix).
- `stage2-ubuntu.sh` is idempotent — re-running won't duplicate `.bashrc` blocks.
- Removed the `pip='uv pip'` alias (broke pip outside virtualenvs).
- `wsl-tools.ps1 clean` actually clears npm/pnpm caches; `restore` sets the
  default user via `wsl --manage`.

### Added
- Go tarball SHA256 verification; golangci-lint via the official installer (v2).
- Optional GPG passphrase protection prompt.
- VS Code: Code Spell Checker, DotENV, Markdown All in One, YAML.

