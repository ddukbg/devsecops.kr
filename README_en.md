# devsecops.kr

[한국어](README.md) | [English](README_en.md)

Resources and check scripts sent through DM by the Instagram DevSecOps magazine [@decsecops.kr](https://www.instagram.com/decsecops.kr/). Links received in DM point to files in this repository.

Every folder has a Korean `README.md` and an English `README_en.md`. Content is based on press reports and vendor advisories, with the verification date noted in each document. Patch timing and operational decisions belong to your organization's security policy.

## Vulnerabilities · CVE response

| Topic | Summary | Docs | Script |
| --- | --- | --- | --- |
| AWS SSM Agent CVE-2026-134069 | Shared SSM registration key on older Windows AMIs; DHMC role credential theft; in-place patch insufficient (keyword `SSM`) | [한국어](aws-ssm-agent-cve-2026-134069/README.md) · [English](aws-ssm-agent-cve-2026-134069/README_en.md) | [audit_ssm_windows_ami.sh](aws-ssm-agent-cve-2026-134069/audit_ssm_windows_ami.sh) |
| NFS2ROOT (CVE-2026-99362) | Unauthenticated remote root in Linux kernel `nfsd`; AWS/EKS scope; fixed kernels | [한국어](cve-2026-99362-nfs2root/README.md) · [English](cve-2026-99362-nfs2root/README_en.md) | [check_nfs2root.sh](cve-2026-99362-nfs2root/check_nfs2root.sh) |
| Java4Shell · NGINX2Shell | OpenJDK AVX-512 VBMI RCE and NGINX HTTP/2 RCE; trigger-condition checks | [한국어](java4shell-nginx2shell/README.md) · [English](java4shell-nginx2shell/README_en.md) | [check_java_nginx_exposure.sh](java4shell-nginx2shell/check_java_nginx_exposure.sh) |
| NGINX CVE-2026-132779 | TLS 1.3 `ssl_early_data` worker CPU exhaustion; 1.31.10/1.30.8 | [한국어](nginx-cve-2026-132779/README.md) · [English](nginx-cve-2026-132779/README_en.md) | — |
| VMware VMSA-2026-0011 | vCenter authentication bypass (CVSS 9.8), ESX I/O filter RCE, fixed builds | [한국어](vmware-vmsa-2026-0011/README.md) · [English](vmware-vmsa-2026-0011/README_en.md) | — |
| Fake Ollama BYOVD + K8s/Cloud Run MCP | Antivirus-killing driver; unauthenticated SSE MCP patches | [한국어](fake-ollama-byovd-mcp/README.md) · [English](fake-ollama-byovd-mcp/README_en.md) | — |

## Cloud · DevOps

| Topic | Summary | Docs | Script/config |
| --- | --- | --- | --- |
| 1Password GitHub incident (#18 · 2026-11-26) | Employee corporate GitHub account taken over → private source code, CI/CD, malicious backend code, customer metadata. Vaults and recovery keys untouched; four controls (keyword `1PASS`) | [한국어](1password-github-breach/README.md) · [English](1password-github-breach/README_en.md) | [audit_github_cicd.sh](1password-github-breach/audit_github_cicd.sh) |
| Cloud secret exposure chain | Rackspace Spot, Radware, Azure APIM, Argo CD; IoCs and rotation order | [한국어](cloud-secrets-exposure/README.md) · [English](cloud-secrets-exposure/README_en.md) | — |
| OpenRouter prompt theft | Limits of ZDR, upstream provider review, token rotation | [한국어](openrouter-prompt-theft/README.md) · [English](openrouter-prompt-theft/README_en.md) | — |
| AWS local emulator | `aws/aws-emulator` IAM, KMS, telemetry constraints | [한국어](aws-emulator/README.md) · [English](aws-emulator/README_en.md) | — |
| Lambda 30-minute timeout | Six traps in concurrency, SQS, NAT, Durable | [한국어](lambda-30min-timeout/README.md) · [English](lambda-30min-timeout/README_en.md) | — |
| AI agent sandboxes | AWS Nitro Sandboxes vs Google Agent CE; NSM PCR key policy | [한국어](agent-sandboxes/README.md) · [English](agent-sandboxes/README_en.md) | [kms_nsm_pcr_policy.json](agent-sandboxes/kms_nsm_pcr_policy.json) |

## Korean incidents · practical defense

| Topic | Summary | Docs |
| --- | --- | --- |
| Danawa full outage (2026-11-26) | Suspected external intrusion; web and app down 15+ hours; confirmed vs unconfirmed, user and operator checklists (keyword `DANAWA`) | [한국어](danawa-service-outage/README.md) · [English](danawa-service-outage/README_en.md) |
| Korean breaches, November 2026 | 37 financial companies, KEPCO, Samsung Securities, KICC; external entry-point checklist | [한국어](korea-breach-tracker-2026-11/README.md) · [English](korea-breach-tracker-2026-11/README_en.md) |
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
# GitHub / CI-CD supply chain audit (read-only, needs gh CLI login)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/1password-github-breach/audit_github_cicd.sh
bash audit_github_cicd.sh ORG/REPO
```

> The documents and scripts here are aids for triage. The scripts are read-only and do not change the system. Check vendor advisories and your organization's policy as well.
