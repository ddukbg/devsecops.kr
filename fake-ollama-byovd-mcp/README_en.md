# Fake Ollama BYOVD + K8s/Cloud Run MCP — distrust the defaults of local AI tools

[한국어](README.md) | [English](README_en.md)

A fake Korean-language Ollama site (`ollama-ko.com`) distributed malware that disables Korean antivirus products. It also installs the official Ollama so nothing looks wrong, while a legitimately signed driver loads into the kernel and tampers with antivirus memory. Internal K8s and Cloud Run MCP servers carry the same class of risk.

## 1. Fake Ollama — BYOVD

| Item | Detail |
| --- | --- |
| Distribution domain | `ollama-ko.com` (official is `ollama.com`) |
| Technique | BYOVD (Bring Your Own Vulnerable Driver) |
| Abused driver | `NeacSafe64.sys` — CVE-2025-45737, **below 1.0.0.8** |
| Concealment | Installs the official Ollama alongside |
| Impact | Antivirus memory tampering |

### Checks

- Block lookalike Korean domains other than the official `ollama.com`
- On suspect PCs, check for the `C:\Windows\System32:msedge.exe` **alternate data stream (ADS)**
- Check for `NeacSafe64.sys` and its version
- Update AhnLab V3 / V3 Lite detection and exception policies

## 2. K8s MCP servers — unauthenticated SSE

| Package | Vulnerable | CVE | Fixed |
| --- | --- | --- | --- |
| `k8s-mcp-server` | < 1.1.0 | CVE-2026-130007 | **>= 1.1.0** |
| `mcp-server-kubernetes` | < 4.2.0 | CVE-2026-134817 | **>= 4.2.0** |

- `k8s-mcp-server` below 1.1.0 defaults to **unauthenticated SSE on `0.0.0.0:8080`**. If the port is reachable, the cluster is writable.
- For HTTP/SSE, force **`127.0.0.1` binding plus `--read-only`** (migrate to STDIO soon).

## 3. Cloud Run MCP — Google's internal integration standard (11/20)

- Ingress: `internal-only` + Egress Agent Gateway / PSC
- Dual authentication: `X-Serverless-Authorization` (IAM) + `Bearer` (OAuth 2.0)
- Private DNS: no `*.run.app` wildcard; peer only the **service FQDN**

## Three checks to run today

1. **Block fake Ollama and verify binaries** — domain, ADS, `NeacSafe64.sys`
2. **Patch K8s MCP and restrict binding** — version, `127.0.0.1`, `--read-only`
3. **Apply the Cloud Run MCP standard** — internal-only, dual auth, FQDN-only peering

> With local LLMs and internal MCP alike, **not trusting the default configuration** is the starting point. Begin with how Ollama is downloaded inside the team and how MCP ports are bound.

## References

- k8s-mcp-server advisory GHSA-m932-63jc-4jqq: https://github.com/reza-gholizade/k8s-mcp-server/security/advisories/GHSA-m932-63jc-4jqq
- Google — Securely connecting internal Cloud Run MCP servers to Gemini Enterprise: https://developers.googleblog.com/how-to-securely-connect-internal-cloud-run-mcp-servers-to-gemini-enterprise/

Verified as of 2026-11-26.
