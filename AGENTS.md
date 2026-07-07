# AGENTS.md — context for AI coding assistants

Provisioning kit for Windows 10/11 + WSL2 Ubuntu dev machines. Bash + PowerShell only; no application code, no package.json.

## Map

| Path | What it is | Runs where |
|------|------------|-----------|
| `windows/stage0-winget.ps1` | Optional Windows apps + Nerd Font via winget | PowerShell (self-elevates) |
| `windows/stage1-windows.ps1` | Enable WSL2, install Ubuntu, generate `.wslconfig` | PowerShell **Admin** |
| `wsl/stage2-ubuntu.sh` | The big installer: languages, CLI tools, git/SSH/GPG, managed `~/.bashrc` block | Ubuntu/WSL |
| `windows/stage3-vscode.ps1` | VS Code: UI extensions local, workspace extensions into the WSL server | PowerShell |
| `windows/wsl-tools.ps1` | Day-2: status/backup/restore/clean/update/reset | PowerShell |
| `wsl/verify-setup.sh` | Read-only 52-check health verifier; exit 0 = healthy | Ubuntu/WSL |
| `demo/` | VHS tape + libs that render the README GIF (`make demo`) | Ubuntu/WSL |
| `tests/profiles/ci.conf` | Selection profile for the CI smoke test | CI |

## Invariants (do not break)

- **Idempotency is CI-enforced**: stage2 runs twice in CI; `~/.bashrc` must be byte-identical after the re-run. The managed block lives between `# Development Environment Configuration` and `# END Development Environment Configuration` markers — always rewrite between markers, never append blindly.
- **Non-interactive mode must stay complete**: every `read` in stage2 is gated by `$NONINTERACTIVE` (flags: `--yes`, `--all`, `--profile FILE`). A new prompt without a non-interactive path breaks CI.
- **Supply chain**: pinned version + in-repo SHA256 where upstream artifacts are stable (Go, nvm installer — use these as the model). Checksum mismatch = hard fail; network failure = `log_warn` and continue.
- **Windows stays clean**: never install dev runtimes on the Windows host.
- **verify-setup.sh is read-only** and its check count (52) is quoted in README + docs — update all three together if you add checks.
- Version numbers live in `CHANGELOG.md` and git tags only — never hardcode a version in a script header or banner. Banners show the runtime `git describe --tags` result (empty for ZIP copies), so they can't drift.

## Conventions

- Logging in bash: `log_step` / `log_info` / `log_success` / `log_warn` / `log_error` (defined at top of stage2). PowerShell: `Write-Step` / `Write-Success` / `Write-Warn` / `Write-Err`.
- Prompts: `[Y/n]` = default yes, `[y/N]` = default no; y/n matching is case-insensitive (`-match '^\s*y'` in PowerShell).
- Shell must pass `shellcheck -S warning`; PowerShell must pass `Invoke-ScriptAnalyzer -Severity Error`.
- Alias changes must be mirrored in README table + `docs/DOCUMENTATION.md` reference + demo tape.

## Verify commands

```bash
make lint      # shellcheck + bash -n over wsl/ and demo/lib/
make verify    # run the health verifier on this machine
GIT_NAME=t GIT_EMAIL=t@e.invalid bash wsl/stage2-ubuntu.sh --profile tests/profiles/ci.conf  # full non-interactive run (mutates the machine!)
```
