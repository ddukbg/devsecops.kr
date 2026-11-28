# devsecops.kr

[한국어](README.md) | [English](README_en.md)

Resources and check scripts sent through DM by the Instagram DevSecOps magazine [@decsecops.kr](https://www.instagram.com/decsecops.kr/). Links received in DM point to files in this repository.

Every folder has a Korean `README.md` and an English `README_en.md`. Content is based on press reports and vendor advisories, with the verification date noted in each document. Patch timing and operational decisions belong to your organization's security policy.

## Technical fundamentals · visual explainers

These come from the Reel series that explains **why** something breaks rather than covering a single incident, and each ships with a check script, payload list or example config.

| Topic | Summary | Docs | Script / example |
| --- | --- | --- | --- |
| SSRF · URL parser differential | A single `?` makes the validator and the client see different destinations; six bypass variants; IMDSv2 hop limit 1 (keyword `SSRF`) | [한국어](ssrf-url-parser-visual/README.md) · [English](ssrf-url-parser-visual/README_en.md) | [safe_url_check.py](ssrf-url-parser-visual/safe_url_check.py) · [ssrf_payloads.txt](ssrf-url-parser-visual/ssrf_payloads.txt) |
| SYN Flood · TCP backlog | SYN queue vs accept queue, what SYN cookies cost, diagnosing with kernel counters (keyword `SYN`) | [한국어](syn-flood-tcp-backlog/README.md) · [English](syn-flood-tcp-backlog/README_en.md) | [check_syn_backlog.sh](syn-flood-tcp-backlog/check_syn_backlog.sh) |
| GitHub OIDC vs static keys | Indefinite `AKIA` keys vs 15 min–1 hour STS credentials, `sub`/`aud` trust policy, migration and retirement order (keyword `OIDC`) | [한국어](github-oidc-vs-static-key/README.md) · [English](github-oidc-vs-static-key/README_en.md) | [oidc_workflow_example.yml](github-oidc-vs-static-key/oidc_workflow_example.yml) · [iam_trust_policy.json](github-oidc-vs-static-key/iam_trust_policy.json) |

## Vulnerabilities · CVE response

| Topic | Summary | Docs | Script |
| --- | --- | --- | --- |
| Jenkins Script Security sandbox escape via partially qualified `@Builder` (CVE-2026-136835 · SECURITY-4278) | A `@builder.Builder` spelling the September fix missed still let Groovy instantiate an arbitrary class at compile time; fixed in script-security `1436.1438.v3dc5ef7d16f2` (core 2.479.3+), same advisory as workflow-cps and warnings-ng (keyword `JENKINS`) | [한국어](jenkins-script-security-cve-2026-136835/README.md) · [English](jenkins-script-security-cve-2026-136835/README_en.md) | [check_jenkins_script_security.sh](jenkins-script-security-cve-2026-136835/check_jenkins_script_security.sh) |
| Traefik Ingress NGINX mTLS header bypass (CVE-2026-137480 · GHSA-ccgh-9g52-6vwg) | Since v3.7.15 client auth applies to the whole host while `Ssl-Client-*` headers were built per Ingress, so an `optional_no_ca` neighbour or an Ingress that does not clear headers forwarded `Ssl-Client-Verify: SUCCESS` and a forged subject to the backend. Fixed in 3.7.18 / 3.8.0-rc.2; v2 unaffected (keyword `MTLS`) | [한국어](traefik-mtls-cve-2026-137480/README.md) · [English](traefik-mtls-cve-2026-137480/README_en.md) | [check_traefik_mtls.sh](traefik-mtls-cve-2026-137480/check_traefik_mtls.sh) |
| Traefik semicolon path authorization bypass (CVE-2026-137481 · GHSA-cp28-5662-543f) | `sanitizePath` leaves `/..;x/` unresolved; when public and protected routers share a Java backend the auth middleware is skipped. Fixed in 2.11.62 / 3.7.18 / 3.8.0-rc.2, plus GitHub CLI 2.106.0 security fixes (keyword `TRAEFIK`) | [한국어](traefik-cve-2026-137481-gh-cli/README.md) · [English](traefik-cve-2026-137481-gh-cli/README_en.md) | [check_traefik_ghcli.sh](traefik-cve-2026-137481-gh-cli/check_traefik_ghcli.sh) |
| Kyverno apiCall URL parser differential (GHSA-pcx2-xcq4-65vf) | `path.Clean` vs `net/url` mismatch bypasses namespace isolation; cluster-scoped reads and Secrets in other namespaces; fixed in 1.19.2 (keyword `KYVERNO`) | [한국어](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README.md) · [English](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README_en.md) | [check_kyverno_parser.sh](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/check_kyverno_parser.sh) |
| AWS SSM Agent CVE-2026-134069 | Shared SSM registration key on older Windows AMIs; DHMC role credential theft; in-place patch insufficient (keyword `SSM`) | [한국어](aws-ssm-agent-cve-2026-134069/README.md) · [English](aws-ssm-agent-cve-2026-134069/README_en.md) | [audit_ssm_windows_ami.sh](aws-ssm-agent-cve-2026-134069/audit_ssm_windows_ami.sh) |
| NFS2ROOT (CVE-2026-99362) | Unauthenticated remote root in Linux kernel `nfsd`; AWS/EKS scope; fixed kernels | [한국어](cve-2026-99362-nfs2root/README.md) · [English](cve-2026-99362-nfs2root/README_en.md) | [check_nfs2root.sh](cve-2026-99362-nfs2root/check_nfs2root.sh) |
| Java4Shell · NGINX2Shell | OpenJDK AVX-512 VBMI RCE and NGINX HTTP/2 RCE; trigger-condition checks | [한국어](java4shell-nginx2shell/README.md) · [English](java4shell-nginx2shell/README_en.md) | [check_java_nginx_exposure.sh](java4shell-nginx2shell/check_java_nginx_exposure.sh) |
| NGINX CVE-2026-132779 | TLS 1.3 `ssl_early_data` worker CPU exhaustion; 1.31.10/1.30.8 | [한국어](nginx-cve-2026-132779/README.md) · [English](nginx-cve-2026-132779/README_en.md) | — |
| VMware VMSA-2026-0011 | vCenter authentication bypass (CVSS 9.8), ESX I/O filter RCE, fixed builds | [한국어](vmware-vmsa-2026-0011/README.md) · [English](vmware-vmsa-2026-0011/README_en.md) | — |
| Fake Ollama BYOVD + K8s/Cloud Run MCP | Antivirus-killing driver; unauthenticated SSE MCP patches | [한국어](fake-ollama-byovd-mcp/README.md) · [English](fake-ollama-byovd-mcp/README_en.md) | — |

## Cloud · DevOps

| Topic | Summary | Docs | Script/config |
| --- | --- | --- | --- |
| AI agent gateways (#21 · 2026-11-27) | Google Workspace MCP/CLI mandate (2027-02-01, 5,000/day) + AWS ELB for Envoy GA (14 Regions, no Seoul). Agent Registry and ELB checklists (keyword `MCP`) | [한국어](ai-agent-mcp-envoy-gateway/README.md) · [English](ai-agent-mcp-envoy-gateway/README_en.md) | [check_agent_gateway_usage.sh](ai-agent-mcp-envoy-gateway/check_agent_gateway_usage.sh) · [checklist](ai-agent-mcp-envoy-gateway/agent-registry-elb-checklist.md) |
| 1Password GitHub incident (#18 · 2026-11-26) | Employee corporate GitHub account taken over → private source code, CI/CD, malicious backend code, customer metadata. Vaults and recovery keys untouched; four controls (keyword `1PASS`) | [한국어](1password-github-breach/README.md) · [English](1password-github-breach/README_en.md) | [audit_github_cicd.sh](1password-github-breach/audit_github_cicd.sh) |
| Cloud secret exposure chain | Rackspace Spot, Radware, Azure APIM, Argo CD; IoCs and rotation order | [한국어](cloud-secrets-exposure/README.md) · [English](cloud-secrets-exposure/README_en.md) | — |
| OpenRouter prompt theft | Limits of ZDR, upstream provider review, token rotation | [한국어](openrouter-prompt-theft/README.md) · [English](openrouter-prompt-theft/README_en.md) | — |
| AWS local emulator | `aws/aws-emulator` IAM, KMS, telemetry constraints | [한국어](aws-emulator/README.md) · [English](aws-emulator/README_en.md) | — |
| Lambda 30-minute timeout | Six traps in concurrency, SQS, NAT, Durable | [한국어](lambda-30min-timeout/README.md) · [English](lambda-30min-timeout/README_en.md) | — |
| AI agent sandboxes | AWS Nitro Sandboxes vs Google Agent CE; NSM PCR key policy | [한국어](agent-sandboxes/README.md) · [English](agent-sandboxes/README_en.md) | [kms_nsm_pcr_policy.json](agent-sandboxes/kms_nsm_pcr_policy.json) |

## Korean incidents · practical defense

| Topic | Summary | Docs |
| --- | --- | --- |
| CJ Olive Young back-office breach (2026-11-26) | Internal work-system account breached: data on 790 employees, partner staff and customers plus 2,406,338 internal member-number records; payment data and passwords untouched; back-office access-control checklist (keyword `OLIVE`) | [한국어](cj-oliveyoung-breach/README.md) · [English](cj-oliveyoung-breach/README_en.md) |
| Danawa full outage (2026-11-26) | Suspected external intrusion; web and app down 15+ hours; confirmed vs unconfirmed, user and operator checklists (keyword `DANAWA`) | [한국어](danawa-service-outage/README.md) · [English](danawa-service-outage/README_en.md) |
| Four Korean breaches in four days (2026-11-28) | Korea Post 113,855 people in one day, Danawa leak admission, E9pay 90+ attacks and KRW 2.5bn, KOFST 210,000 records across 16 fields; lookup-API authorisation, withdrawal controls and impersonation checklists (keyword `DOMINO`) | [한국어](kr-breach-domino-2026-11-28/README.md) · [English](kr-breach-domino-2026-11-28/README_en.md) |
| Korean breaches, November 2026 | 37 financial companies, KEPCO, Samsung Securities, KICC, CJ Olive Young, Danawa, Suhyup Bank, Hotel Story; KEPCO data-for-sale status and external entry-point checklist | [한국어](korea-breach-tracker-2026-11/README.md) · [English](korea-breach-tracker-2026-11/README_en.md) |
| Securities API defense rulebook | RFC 8693 token exchange, Redis HLL rate limiting, MyBatis `${}` blocking | [한국어](securities-api-defense/README.md) · [English](securities-api-defense/README_en.md) |
| Crypto exchange breaches | Bithumb's 15-day intrusion; groupware, vendors, hot wallets | [한국어](crypto-exchange-breaches/README.md) · [English](crypto-exchange-breaches/README_en.md) |

## AI security

| Topic | Summary | Docs |
| --- | --- | --- |
| AI agent intrusions | EU Commission, Korean universities, finance; ARTEX/Storm-0940/KimJEN | [한국어](ai-agent-attacks/README.md) · [English](ai-agent-attacks/README_en.md) |
| Six security AI agents | Red/Blue tool comparison and adoption guardrails | [한국어](ai-security-agents/README.md) · [English](ai-security-agents/README_en.md) |
| OpenShell (CNCF) | Kernel-level agent isolation; 0.1.x limits | [한국어](openshell-cncf/README.md) · [English](openshell-cncf/README_en.md) |
| Claude CVP + Mythos | Tier requirements, static key ban on 12/15, practical use | [한국어](claude-cvp-mythos/README.md) · [English](claude-cvp-mythos/README_en.md) |

## Document security

| Topic | Summary | Docs | Script |
| --- | --- | --- | --- |
| PDF redaction | The black-box trap, metadata removal, CI extraction gate | [한국어](pdf-redaction-ci/README.md) · [English](pdf-redaction-ci/README_en.md) | [check_pdf_redaction.sh](pdf-redaction-ci/check_pdf_redaction.sh) |

## Quick checks

```bash
# NFS2ROOT exposure check (read-only, CSV aggregation)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/cve-2026-99362-nfs2root/check_nfs2root.sh
sudo bash check_nfs2root.sh --csv
```

```bash
# Java4Shell / NGINX2Shell trigger conditions
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/java4shell-nginx2shell/check_java_nginx_exposure.sh
bash check_java_nginx_exposure.sh
```

```bash
# PDF redaction CI gate (requires poppler-utils)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/pdf-redaction-ci/check_pdf_redaction.sh
bash check_pdf_redaction.sh document.pdf
```

```bash
# AWS Windows AMI / SSM Agent / DHMC exposure check (read-only)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/aws-ssm-agent-cve-2026-134069/audit_ssm_windows_ami.sh
bash audit_ssm_windows_ami.sh
```

```bash
# Traefik versions, access-log traces and gh CLI version (read-only)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/traefik-cve-2026-137481-gh-cli/check_traefik_ghcli.sh
bash check_traefik_ghcli.sh --context prod
```

```bash
# Kyverno version and namespaced Policy apiCall exposure check (read-only)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/kyverno-url-parser-ghsa-pcx2-xcq4-65vf/check_kyverno_parser.sh
bash check_kyverno_parser.sh --context prod
```

```bash
# GitHub / CI-CD supply chain audit (read-only, needs gh CLI login)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/1password-github-breach/audit_github_cicd.sh
bash audit_github_cicd.sh ORG/REPO
```

```bash
# SYN queue / accept queue audit (read-only, needs iproute2)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/syn-flood-tcp-backlog/check_syn_backlog.sh
bash check_syn_backlog.sh --csv > syn_audit.csv
```

```bash
# SSRF validator comparison (no outbound requests, standard library only)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/ssrf-url-parser-visual/safe_url_check.py
python3 safe_url_check.py
```

```bash
# AI agent access audit: Workspace REST calls and Envoy proxy posture (read-only)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/ai-agent-mcp-envoy-gateway/check_agent_gateway_usage.sh
bash check_agent_gateway_usage.sh --dir .
```

```bash
# Jenkins Script Security sandbox escape (CVE-2026-136835) exposure check (read-only)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/jenkins-script-security-cve-2026-136835/check_jenkins_script_security.sh
bash check_jenkins_script_security.sh --url "$JENKINS_URL" --user bot --token "$TOKEN" --jenkins-home /var/lib/jenkins
```

> The documents and scripts here are aids for triage. The scripts are read-only and do not change the system. Check vendor advisories and your organization's policy as well.
