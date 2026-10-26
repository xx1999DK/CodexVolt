# Contributing

Issues and pull requests are welcome. Describe the macOS version, CPU architecture,
Codex CLI version and steps to reproduce. Remove account identifiers, tokens and
private paths from logs and screenshots before posting.

Run `bash scripts/test.sh` and `bash scripts/build.sh` on macOS before submitting.
Keep the app native, small and idle-friendly. New themes should remain legible at
54×22 pt and 46×22 pt, including 0%, 100%, missing and stale values.

Quota data is read-only. Do not add credential copying, token logging or model calls
to the polling path. Changes to quota parsing should include a focused regression
case in `Tests/QuotaTests.swift`.
