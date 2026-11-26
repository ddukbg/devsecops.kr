# AWS's official local emulator `aws/aws-emulator` — constraints to know before using it in CI

[한국어](README.md) | [English](README_en.md)

A free local emulator released by AWS itself. A single Rust binary runs 438 API models (200+ services) locally, and the CC0-1.0 license lets you use it in CI/CD with no account or billing. But **passing local tests does not make a production deployment safe.**

## At a glance

| Item | Detail |
| --- | --- |
| Repository | https://github.com/aws/aws-emulator |
| Implementation | Single Rust binary |
| Scope | 438 API models / 200+ services |
| Endpoint | `127.0.0.1:9297` |
| License | CC0-1.0 |
| Right after launch | GitHub 9.9K★ |

## Four practical constraints

1. **IAM bypass** — Permissions Boundary, Session Policy, and unauthorized `sts:AssumeRole` can pass. DevOps-Daily measured 32 IAM cases and only 27 matched real AWS.
2. **Scope limits** — KMS key policies, cross-account, and multi-region are unsupported (us-east-1 only).
3. **Code is not isolated** — Lambda and other function code runs directly with the host user's privileges. Do not run untrusted code.
4. **Telemetry is on by default** — turn it off on internal networks and in CI.

```bash
# Disable telemetry
aws-emulator --telemetry off
# Or via environment variable
export EMULATOR_TELEMETRY=off
```

## Using it in CI

- Use the emulator only for **unit and integration tests**; verify IAM, KMS, and cross-account behavior in a temporary real AWS account.
- Do not build a deployment approval pipeline on emulator results alone.
- Keep the network bound to `127.0.0.1` and do not expose it outside the CI runner.

## References

- GitHub — aws/aws-emulator: https://github.com/aws/aws-emulator
- AWS — Emulator security constraints: https://docs.aws.amazon.com/emulator/latest/userguide/security.html
- DevOps-Daily — 32 IAM permission tests: https://devops-daily.com/posts/aws-emulator-hands-on-test

Verified as of 2026-11-26. The emulator moves quickly; check release notes.
