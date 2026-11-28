# devsecops.kr

[한국어](README.md) | [English](README_en.md)

Resources and check scripts sent through DM by the Instagram DevSecOps magazine [@devsecops.kr](https://www.instagram.com/devsecops.kr/). Links received in DM point to files in this repository.

Folders are grouped into topic collections. Pick a topic below; every folder has a Korean `README.md` and an English `README_en.md`. Content is based on press reports and vendor advisories, with the verification date noted in each document. Patch timing and operational decisions belong to your organization's security policy.

**DM keywords** are the comment keywords printed in each post's caption. Leave the keyword in a comment and the matching resources and key checks arrive by DM.

## Latest

| Date | Topic | DM keyword |
| --- | --- | --- |
| 11-28 | [Claude's Riemann proof, does it break encryption?](claude-riemann-hypothesis-security/README_en.md) — RSA-2048, ECC and PQC unaffected; 1024-bit RSA lifetime and a four-step check | `RIEMANN` |
| 11-28 | [KEPCO: encrypted at rest, leaked in plaintext](kepco-plaintext-exfiltration/README_en.md) — 650,487 customers' records left decrypted with no key leakage | `PLAIN` |
| 11-28 | [Four Korean breaches in four days](kr-breach-domino-2026-11-28/README_en.md) — Korea Post, Danawa, E9pay, KOFST | `DOMINO` |
| 11-27 | [Traefik mTLS header bypass](traefik-mtls-cve-2026-137480/README_en.md) — forged `Ssl-Client-*` headers, fixed in 3.7.18 | `MTLS` |
| 11-27 | [Jenkins Script Security sandbox escape](jenkins-script-security-cve-2026-136835/README_en.md) — `@Builder` runs at compile time | `JENKINS` |
| 11-27 | [AI agent gateways](ai-agent-mcp-envoy-gateway/README_en.md) — Workspace MCP mandate and ELB for Envoy | `MCP` |

## Collections

- [🚨 Korean incidents & data breaches](#kr-breach) — 7
- [☸️ Kubernetes · cloud · network](#k8s-cloud) — 11
- [🔧 CI/CD · supply chain · runtime](#cicd) — 5
- [🤖 AI security · practical guides](#ai-guide) — 10
- [Quick checks](#quick) — runnable read-only scripts

<a id="kr-breach" name="kr-breach"></a>
## 🚨 Korean incidents & data breaches

Breaches confirmed in Korea, plus the defence rules pulled out of each one.

| Topic | Summary | DM keyword | Docs |
| --- | --- | --- | --- |
| Korean breaches, November 2026 | 37 financial companies, KEPCO, Samsung Securities, KICC, CJ Olive Young, Danawa, Suhyup Bank, Hotel Story — the external entry points that keep getting hit, with lookup and response checklists | `KR` `DOSSIER` `FIN` `KICC` `KEPCO` `SAMSUNG` `VOC` | [KR](korea-breach-tracker-2026-11/README.md) · [EN](korea-breach-tracker-2026-11/README_en.md) |
| Four Korean breaches in four days (2026-11-28) | Korea Post 113,855 people in one day, Danawa leak admission, E9pay 90+ attacks and KRW 2.5bn, KOFST 210,000 records — lookup-API authorisation and withdrawal controls | `DOMINO` | [KR](kr-breach-domino-2026-11-28/README.md) · [EN](kr-breach-domino-2026-11-28/README_en.md) |
| KEPCO: encrypted at rest, leaked in plaintext | Why encryption at rest cannot stop the app/API decryption layer; response minimisation and object-level authorisation checklists | `PLAIN` | [KR](kepco-plaintext-exfiltration/README.md) · [EN](kepco-plaintext-exfiltration/README_en.md) |
| CJ Olive Young back-office breach | Internal work-system account breached: 790 employees, partners and customers plus 2,406,338 member-number records; payment data and passwords untouched | `OLIVE` | [KR](cj-oliveyoung-breach/README.md) · [EN](cj-oliveyoung-breach/README_en.md) |
| Danawa full outage | Suspected external intrusion, web and app down 15+ hours; confirmed vs unconfirmed, user and operator checklists | `DANAWA` | [KR](danawa-service-outage/README.md) · [EN](danawa-service-outage/README_en.md) |
| Crypto exchange breaches | Bithumb's 15-day intrusion — the way in was groupware, vendor agents and hot wallets, not cold wallets | `CRYPTO` | [KR](crypto-exchange-breaches/README.md) · [EN](crypto-exchange-breaches/README_en.md) |
| Securities API defense rulebook | The three holes written into a 77,545-person breach report — RFC 8693 token exchange, Redis HLL rate limiting, MyBatis `${}` blocking | `SECURITIES` | [KR](securities-api-defense/README.md) · [EN](securities-api-defense/README_en.md) |

<a id="k8s-cloud" name="k8s-cloud"></a>
## ☸️ Kubernetes · cloud · network

Where infrastructure actually breaks: proxies, ingress controllers, cluster policy, kernels and load balancers.

| Topic | Summary | DM keyword | Docs |
| --- | --- | --- | --- |
| Traefik Ingress NGINX mTLS header bypass (CVE-2026-137480) | Client auth applies per host since v3.7.15 while `Ssl-Client-*` headers are built per Ingress, so an `optional_no_ca` neighbour lets a forged `Ssl-Client-Verify: SUCCESS` through; fixed in 3.7.18 / 3.8.0-rc.2 | `MTLS` | [KR](traefik-mtls-cve-2026-137480/README.md) · [EN](traefik-mtls-cve-2026-137480/README_en.md) |
| Traefik semicolon path authorization bypass (CVE-2026-137481) | `sanitizePath` leaves `/..;x/` unresolved, so public and protected routers sharing a Java backend skip auth middleware; 2.11.62 / 3.7.18 | `TRAEFIK` | [KR](traefik-cve-2026-137481-gh-cli/README.md) · [EN](traefik-cve-2026-137481-gh-cli/README_en.md) |
| Kyverno apiCall URL parser differential (GHSA-pcx2-xcq4-65vf) | A `?x=/namespaces/{ns}/` decoy passes validation while the executor drops everything after `?`, reading cluster-scoped resources and Secrets in other namespaces; fixed in 1.19.2 | `KYVERNO` | [KR](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README.md) · [EN](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README_en.md) |
| AWS SSM Agent (CVE-2026-134069) | Windows AMIs before 2026-09-09 share one SSM registration key; DHMC role credential theft; in-place patch does not fix it | `SSM` | [KR](aws-ssm-agent-cve-2026-134069/README.md) · [EN](aws-ssm-agent-cve-2026-134069/README_en.md) |
| NFS2ROOT (CVE-2026-99362) | Unauthenticated remote root in Linux kernel `nfsd`; AWS/EKS scope test and fixed kernels | `NFS` | [KR](cve-2026-99362-nfs2root/README.md) · [EN](cve-2026-99362-nfs2root/README_en.md) |
| SSRF · URL parser differential | One `?` makes the validator and the client see different destinations; six bypass variants and IMDSv2 hop limit 1 | `SSRF` | [KR](ssrf-url-parser-visual/README.md) · [EN](ssrf-url-parser-visual/README_en.md) |
| SYN Flood · TCP backlog | An attack that fills the queue, not the link; SYN queue vs accept queue and kernel counters | `SYN` | [KR](syn-flood-tcp-backlog/README.md) · [EN](syn-flood-tcp-backlog/README_en.md) |
| Cloud secret exposure chain | Rackspace Spot, Radware WAF, Azure APIM, Argo CD — IoCs and rotation order by issuer | `SPOT` `SECRET` | [KR](cloud-secrets-exposure/README.md) · [EN](cloud-secrets-exposure/README_en.md) |
| AWS local emulator | `aws/aws-emulator` covers 438 API models, but a green local test is not production safety — IAM, KMS and telemetry limits | `AWS` | [KR](aws-emulator/README.md) · [EN](aws-emulator/README_en.md) |
| Lambda 30-minute timeout | Raising `--timeout 1800` alone breaks concurrency, SQS visibility and NAT keep-alive: six traps | `LAMBDA` | [KR](lambda-30min-timeout/README.md) · [EN](lambda-30min-timeout/README_en.md) |
| VMware VMSA-2026-0011 | vCenter authentication bypass (CVSS 9.8) and ESX I/O filter RCE; separate from last week's zero-day, check again | `VMWARE` | [KR](vmware-vmsa-2026-0011/README.md) · [EN](vmware-vmsa-2026-0011/README_en.md) |

<a id="cicd" name="cicd"></a>
## 🔧 CI/CD · supply chain · runtime

Breaches that start from build pipelines, developer accounts and deployment credentials, plus runtime CVEs in what those pipelines ship (JDK, NGINX).

| Topic | Summary | DM keyword | Docs |
| --- | --- | --- | --- |
| 1Password GitHub account breach | One employee's corporate GitHub account led to private source copies, CI/CD access and malicious backend code; four controls (no classic PATs, CODEOWNERS, OIDC, recovery-code handling) | `1PASS` | [KR](1password-github-breach/README.md) · [EN](1password-github-breach/README_en.md) |
| Jenkins Script Security `@Builder` sandbox escape (CVE-2026-136835) | Arbitrary class constructors run at compile time, before the sandbox is applied; script-security `1436.1438.v3dc5ef7d16f2`, core 2.479.3+ | `JENKINS` | [KR](jenkins-script-security-cve-2026-136835/README.md) · [EN](jenkins-script-security-cve-2026-136835/README_en.md) |
| GitHub Actions OIDC vs static keys | Instead of an indefinite `AKIA` key, 15 min–1 hour STS credentials checked against `sub`/`aud`; migration, retirement and common traps | `OIDC` | [KR](github-oidc-vs-static-key/README.md) · [EN](github-oidc-vs-static-key/README_en.md) |
| Java4Shell · NGINX2Shell | OpenJDK AVX-512 VBMI RCE and NGINX HTTP/2 RCE — check the CPU instruction set and proxy settings first | `JAVA` | [KR](java4shell-nginx2shell/README.md) · [EN](java4shell-nginx2shell/README_en.md) |
| NGINX CVE-2026-132779 | With TLS 1.3 `ssl_early_data`, an unauthenticated client pins worker CPU at 100%; 1.31.10 / 1.30.8 | `NGINX` | [KR](nginx-cve-2026-132779/README.md) · [EN](nginx-cve-2026-132779/README_en.md) |

> The seven GitHub CLI 2.106.0 security fixes are documented in the [Traefik semicolon path bypass](traefik-cve-2026-137481-gh-cli/README_en.md) folder.

<a id="ai-guide" name="ai-guide"></a>
## 🤖 AI security · practical guides

For teams deploying agents and teams defending against them, plus hands-on guides for documents and data.

### AI security

| Topic | Summary | DM keyword | Docs |
| --- | --- | --- | --- |
| Claude, the Riemann hypothesis and encryption | The proof does not break RSA — unconditional GRH results, the AI × Lean verification turning point, retiring 1024-bit RSA and crypto-agility | `RIEMANN` | [KR](claude-riemann-hypothesis-security/README.md) · [EN](claude-riemann-hypothesis-security/README_en.md) |
| AI agent gateways | Google Workspace restricts direct REST calls from agents (2027-02-01) and AWS opens ELB for Envoy GA — both funnel inspection and patching through one gateway | `MCP` | [KR](ai-agent-mcp-envoy-gateway/README.md) · [EN](ai-agent-mcp-envoy-gateway/README_en.md) |
| AI agent intrusions | EU Commission, Korean universities, finance and diplomacy; ARTEX / Storm-0940 / KimJEN automating recon, intrusion and defacement | `AI` | [KR](ai-agent-attacks/README.md) · [EN](ai-agent-attacks/README_en.md) |
| Six security AI agents | Red/Blue team open-source comparison and in-house adoption guardrails | `AGENT` | [KR](ai-security-agents/README.md) · [EN](ai-security-agents/README_en.md) |
| Claude CVP + Mythos | Anthropic's approval programme for defenders using relaxed guardrails; tier conditions and the 12/15 static-key ban | `CVP` | [KR](claude-cvp-mythos/README.md) · [EN](claude-cvp-mythos/README_en.md) |
| AI agent sandboxes | AWS Nitro Sandboxes vs Google Agent CE — hardware isolation beyond containers and NSM PCR key policy | `SANDBOX` | [KR](agent-sandboxes/README.md) · [EN](agent-sandboxes/README_en.md) |
| OpenShell (CNCF) | Open-source runtime isolating agents at the OS kernel level; 0.1.x limits | `OPEN` | [KR](openshell-cncf/README.md) · [EN](openshell-cncf/README_en.md) |
| Fake Ollama BYOVD + MCP | A fake Korean Ollama site shipping an antivirus-killing driver, and unauthenticated SSE MCP server patches | `OLLAMA` | [KR](fake-ollama-byovd-mcp/README.md) · [EN](fake-ollama-byovd-mcp/README_en.md) |
| OpenRouter prompt theft | ZDR protects only the first hop — upstream inference provider review and token rotation | `OPENROUTER` | [KR](openrouter-prompt-theft/README.md) · [EN](openrouter-prompt-theft/README_en.md) |

### Practical guides

| Topic | Summary | DM keyword | Docs |
| --- | --- | --- | --- |
| PDF redaction | A black box is not a deletion — why 230 people's data was recoverable from ten court rulings, plus metadata stripping and a CI extraction gate | `PDF` | [KR](pdf-redaction-ci/README.md) · [EN](pdf-redaction-ci/README_en.md) |

<a id="quick" name="quick"></a>
## Quick checks

Every script is read-only and does not change the system.

```bash
# Legacy RSA, SHA-1 certificate and DKIM key check (read-only)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/claude-riemann-hypothesis-security/check_legacy_rsa_certs.sh
bash check_legacy_rsa_certs.sh --hosts hosts.txt --csv
```

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
# Traefik mTLS host / Ingress annotation / header stripping check (read-only)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/traefik-mtls-cve-2026-137480/check_traefik_mtls.sh
bash check_traefik_mtls.sh --context prod
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

> The documents and scripts here are aids for triage. Check vendor advisories and your organization's policy as well.
