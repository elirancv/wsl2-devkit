# Contributing to wsl2-devkit

Thanks for considering a contribution. This project values small, verifiable changes over big rewrites.

## Ground Rules

The two invariants every change must preserve:

1. **Idempotency** — every script must be safe to re-run. CI enforces this literally: Stage 2 runs twice on a clean runner and the managed `~/.bashrc` block must be byte-identical after the second run.
1. **Windows stays clean** — dev tooling lands in WSL, never on the Windows host. UI-level things (editors, fonts, Remote clients) stay on Windows.

## Local Development

Work inside WSL:

```bash
make lint      # bash -n + shellcheck on all shell scripts (must be clean)
make verify    # run the 52-check health verifier against your machine
make demo      # re-render the README GIF after user-visible CLI changes
```

PowerShell changes are linted by PSScriptAnalyzer in CI (error severity blocks).
To check locally on Windows: `Invoke-ScriptAnalyzer -Path windows -Recurse`.

To exercise the installer end-to-end without prompts:

```bash
GIT_NAME="Test" GIT_EMAIL="test@example.invalid" ./wsl/stage2-ubuntu.sh --profile tests/profiles/ci.conf
```

## Supply-Chain Rules

- New downloads must be TLS-only (`--proto '=https' --tlsv1.2`) from the vendor's official domain.
- If the upstream publishes stable artifacts, **pin the version and commit the SHA256 in-repo** (see the Go and nvm installs in `wsl/stage2-ubuntu.sh` as the model). A checksum fetched at runtime from the same origin as the artifact does not count as verification.
- Checksum mismatches must hard-fail; plain network failures should degrade to a `log_warn` so a flaky mirror can't abort the whole run.

### Bumping the Go pin

```bash
make bump-go   # fetches the latest release + checksums and rewrites the pin in-place
```

Review the diff it prints, then commit. (It updates `GO_VERSION`, `GO_SHA256_AMD64`, and `GO_SHA256_ARM64` together in `wsl/stage2-ubuntu.sh` from `go.dev/dl/?mode=json`.)

## Pull Requests

- Branch from `main`; one logical change per PR.
- CI must be green: ShellCheck, PSScriptAnalyzer, and the twice-run smoke test.
- Update docs in the same PR — `README.md` for user-facing changes, `docs/DOCUMENTATION.md` for reference detail, and a `CHANGELOG.md` entry under an Unreleased/next-version heading.
- If you add or rename an alias, update **both** alias tables (README + DOCUMENTATION) and the demo tape if it appears there.

## Releasing (maintainers)

1. Land a CHANGELOG entry for the new version via PR (Keep-a-Changelog format; the CHANGELOG is the only place versions live).
1. From the CI-green merge commit on `main`:

   ```bash
   make checksums                       # writes checksums.txt (SHA256 of every script)
   git tag -a vX.Y.Z -m "vX.Y.Z - summary" <merge-sha>
   git push origin vX.Y.Z
   gh release create vX.Y.Z --title "vX.Y.Z — summary" \
     --notes-file <notes.md> "checksums.txt#checksums.txt (SHA256 of every script)"
   ```

1. Release notes: highlights + PR references + the `sha256sum -c checksums.txt` verify snippet. Tag only commits whose exact tree passed CI.

## Reporting Issues

Bug reports with the output of `make verify` and your Windows build number (`winver`) get fixed fastest.
Security issues: see [SECURITY.md](SECURITY.md) — do not open a public issue.
