# Security Policy

## Supported Versions

Only the latest tagged release is supported.
Audit and run a tagged release (verify with its attached `checksums.txt`), not `main`.

| Version | Supported |
|---------|-----------|
| Latest release (currently v5.x) | ✅ |
| Older tags / `main` between releases | ❌ |

## Reporting a Vulnerability

Please **do not** open a public issue for security problems.

Use GitHub's private reporting instead: **Security → Report a vulnerability** on this repository ([direct link](https://github.com/elirancv/wsl2-devkit/security/advisories/new)).
You can expect an acknowledgement within a few days.

## Scope Notes

Things worth knowing before reporting:

- These scripts intentionally run with the user's privileges (Stage 1 requires Windows Administrator) and provision a machine — "the script can modify your system" is by design, not a vulnerability.
- WSL2 is a **resource** boundary, not a security boundary: Windows↔WSL interop is bidirectional by default, so compromise of either side implies compromise of the user context on both. See the "Security & trust" section of the [README](README.md#security--trust).
- In scope: anything that lets a *third party* influence what the scripts download or execute — checksum bypasses, downgrade of pinned versions, URL/argument injection, credential or key exposure.
