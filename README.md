# devsecops.kr

[한국어](README.md) | [English](README_en.md)

인스타그램 DevSecOps 매거진 [@decsecops.kr](https://www.instagram.com/decsecops.kr/) DM으로 보낸 자료와 점검 스크립트 모음입니다. DM으로 받은 링크는 이 저장소의 파일을 가리킵니다.

각 폴더는 같은 이름의 한국어 `README.md`와 영어 `README_en.md`로 구성됩니다. 보도·벤더 공지 기준으로 정리했고, 확인 기준일은 문서마다 표기했습니다. 패치 적용과 운영 판단은 소속 조직의 보안 정책을 따르세요.

## 기술 원리 · 시각화

취약점 한 건이 아니라 **왜 그렇게 뚫리는지**를 다룬 기술 시각화(릴스) 정리본입니다. 점검 스크립트·페이로드·예제 설정이 같이 들어 있습니다.

| 주제 | 내용 | 문서 | 스크립트/예제 |
| --- | --- | --- | --- |
| SSRF · URL 파서 불일치 | `?` 하나로 검증기와 클라이언트가 다른 목적지를 본다, 우회 6종, IMDSv2 hop limit 1 (키워드 `SSRF`) | [한국어](ssrf-url-parser-visual/README.md) · [English](ssrf-url-parser-visual/README_en.md) | [safe_url_check.py](ssrf-url-parser-visual/safe_url_check.py) · [ssrf_payloads.txt](ssrf-url-parser-visual/ssrf_payloads.txt) |
| SYN Flood · TCP 백로그 | SYN queue와 accept queue 구분, SYN cookie의 대가, 커널 카운터 진단 (키워드 `SYN`) | [한국어](syn-flood-tcp-backlog/README.md) · [English](syn-flood-tcp-backlog/README_en.md) | [check_syn_backlog.sh](syn-flood-tcp-backlog/check_syn_backlog.sh) |
| GitHub OIDC vs 정적 키 | 무기한 AKIA 키와 15분~1시간 STS 자격증명, `sub`·`aud` 신뢰 정책, 전환·폐기 순서 (키워드 `OIDC`) | [한국어](github-oidc-vs-static-key/README.md) · [English](github-oidc-vs-static-key/README_en.md) | [oidc_workflow_example.yml](github-oidc-vs-static-key/oidc_workflow_example.yml) · [iam_trust_policy.json](github-oidc-vs-static-key/iam_trust_policy.json) |

## 취약점 · CVE 대응

| 주제 | 내용 | 문서 | 스크립트 |
| --- | --- | --- | --- |
| Traefik 세미콜론 경로 인증 우회 (CVE-2026-137481 · GHSA-cp28-5662-543f) | `sanitizePath`가 `/..;x/`를 남겨 공개·보호 라우터가 같은 Java 백엔드를 공유하면 인증 미들웨어 우회, 2.11.62/3.7.18/3.8.0-rc.2 + GitHub CLI 2.106.0 보안 7건 (키워드 `TRAEFIK`) | [한국어](traefik-cve-2026-137481-gh-cli/README.md) · [English](traefik-cve-2026-137481-gh-cli/README_en.md) | [check_traefik_ghcli.sh](traefik-cve-2026-137481-gh-cli/check_traefik_ghcli.sh) |
| Kyverno apiCall URL 파서 불일치 (GHSA-pcx2-xcq4-65vf) | `path.Clean` vs `net/url` 파싱 차이로 네임스페이스 격리 우회, 클러스터 전역 자원·타 네임스페이스 Secret 열람, 1.19.2 (키워드 `KYVERNO`) | [한국어](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README.md) · [English](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README_en.md) | [check_kyverno_parser.sh](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/check_kyverno_parser.sh) |
| AWS SSM Agent CVE-2026-134069 | 구형 Windows AMI의 SSM 등록 키 공유, DHMC Role 탈취, 인플레이스 패치 무효 (키워드 `SSM`) | [한국어](aws-ssm-agent-cve-2026-134069/README.md) · [English](aws-ssm-agent-cve-2026-134069/README_en.md) | [audit_ssm_windows_ami.sh](aws-ssm-agent-cve-2026-134069/audit_ssm_windows_ami.sh) |
| NFS2ROOT (CVE-2026-99362) | 리눅스 커널 `nfsd` 무인증 원격 루트, AWS·EKS 판별, 고정 커널 | [한국어](cve-2026-99362-nfs2root/README.md) · [English](cve-2026-99362-nfs2root/README_en.md) | [check_nfs2root.sh](cve-2026-99362-nfs2root/check_nfs2root.sh) |
| Java4Shell · NGINX2Shell | OpenJDK AVX-512 VBMI RCE, NGINX HTTP/2 RCE, 발동 조건 점검 | [한국어](java4shell-nginx2shell/README.md) · [English](java4shell-nginx2shell/README_en.md) | [check_java_nginx_exposure.sh](java4shell-nginx2shell/check_java_nginx_exposure.sh) |
| NGINX CVE-2026-132779 | TLS 1.3 `ssl_early_data` 워커 CPU 고갈, 1.31.10/1.30.8 | [한국어](nginx-cve-2026-132779/README.md) · [English](nginx-cve-2026-132779/README_en.md) | — |
| VMware VMSA-2026-0011 | vCenter 인증 우회(CVSS 9.8), ESX I/O 필터 RCE, 버전별 빌드 | [한국어](vmware-vmsa-2026-0011/README.md) · [English](vmware-vmsa-2026-0011/README_en.md) | — |
| 가짜 Ollama BYOVD + K8s·Cloud Run MCP | 백신 무력화 드라이버, 무인증 SSE MCP 패치 | [한국어](fake-ollama-byovd-mcp/README.md) · [English](fake-ollama-byovd-mcp/README_en.md) | — |

## 클라우드 · DevOps

| 주제 | 내용 | 문서 | 스크립트/설정 |
| --- | --- | --- | --- |
| AI 에이전트 게이트웨이 (#21 · 2026-11-27) | Google Workspace MCP/CLI 의무화(2027-02-01, 5,000건/일) + AWS ELB for Envoy GA(14개 리전, 서울 없음). Agent Registry·ELB 점검 체크리스트 (키워드 `MCP`) | [한국어](ai-agent-mcp-envoy-gateway/README.md) · [English](ai-agent-mcp-envoy-gateway/README_en.md) | [check_agent_gateway_usage.sh](ai-agent-mcp-envoy-gateway/check_agent_gateway_usage.sh) · [체크리스트](ai-agent-mcp-envoy-gateway/agent-registry-elb-checklist.md) |
| 1Password GitHub 침해 (#18 · 2026-11-26) | 직원 기업 GitHub 계정 탈취 → 비공개 소스코드·CI/CD·백엔드 악성코드, 고객 메타데이터 유출. 볼트·복구 키는 비노출, 4대 통제 (키워드 `1PASS`) | [한국어](1password-github-breach/README.md) · [English](1password-github-breach/README_en.md) | [audit_github_cicd.sh](1password-github-breach/audit_github_cicd.sh) |
| 클라우드 시크릿 연쇄 노출 | Rackspace Spot·Radware·Azure APIM·Argo CD, IoC와 키 로테이션 순서 | [한국어](cloud-secrets-exposure/README.md) · [English](cloud-secrets-exposure/README_en.md) | — |
| OpenRouter 프롬프트 탈취 | ZDR의 한계, 업스트림 제공자 점검, 토큰 로테이션 | [한국어](openrouter-prompt-theft/README.md) · [English](openrouter-prompt-theft/README_en.md) | — |
| AWS 로컬 에뮬레이터 | `aws/aws-emulator` IAM·KMS·텔레메트리 제약 | [한국어](aws-emulator/README.md) · [English](aws-emulator/README_en.md) | — |
| Lambda 30분 타임아웃 | 동시성·SQS·NAT·Durable 6가지 함정 | [한국어](lambda-30min-timeout/README.md) · [English](lambda-30min-timeout/README_en.md) | — |
| AI 에이전트 샌드박스 | AWS Nitro Sandboxes vs Google Agent CE, NSM PCR 키 정책 | [한국어](agent-sandboxes/README.md) · [English](agent-sandboxes/README_en.md) | [kms_nsm_pcr_policy.json](agent-sandboxes/kms_nsm_pcr_policy.json) |

## 국내 사고 · 실무 방어

| 주제 | 내용 | 문서 |
| --- | --- | --- |
| CJ올리브영 업무시스템 침해 (2026-11-26) | 업무망 계정 침해로 임직원·협력사·고객 790명 정보와 내부 관리용 회원번호 자료 240만 6,338건 유출, 결제정보·비밀번호는 비노출, 백오피스 접근통제 체크리스트 (키워드 `OLIVE`) | [한국어](cj-oliveyoung-breach/README.md) · [English](cj-oliveyoung-breach/README_en.md) |
| 다나와 서비스 전면 중단 (2026-11-26) | 외부 침해 추정 사고로 웹·앱 15시간+ 중단, 확인·미확인 구분과 이용자·운영팀 체크리스트 (키워드 `DANAWA`) | [한국어](danawa-service-outage/README.md) · [English](danawa-service-outage/README_en.md) |
| 2026년 11월 국내 유출 정리 | 금융권 37곳·한전·삼성증권·KICC·CJ올리브영·다나와·수협은행 등, 외부 접점 체크리스트 | [한국어](korea-breach-tracker-2026-11/README.md) · [English](korea-breach-tracker-2026-11/README_en.md) |
| 증권사 API 방어 룰북 | RFC 8693 인증변환, Redis HLL 레이트리밋, MyBatis `${}` 차단 | [한국어](securities-api-defense/README.md) · [English](securities-api-defense/README_en.md) |
| 가상자산 거래소 연쇄 침해 | 빗썸 15일 침입, 그룹웨어·외주·핫월렛 | [한국어](crypto-exchange-breaches/README.md) · [English](crypto-exchange-breaches/README_en.md) |

## AI 보안

| 주제 | 내용 | 문서 |
| --- | --- | --- |
| AI 에이전트 침해 사례 | EU 집행위·국내 대학·금융, ARTEX/Storm-0940/KimJEN | [한국어](ai-agent-attacks/README.md) · [English](ai-agent-attacks/README_en.md) |
| 보안팀 AI 에이전트 6선 | Red/Blue 팀별 도구와 도입 가드레일 | [한국어](ai-security-agents/README.md) · [English](ai-security-agents/README_en.md) |
| OpenShell (CNCF) | 커널 수준 에이전트 격리, 0.1.x 한계 | [한국어](openshell-cncf/README.md) · [English](openshell-cncf/README_en.md) |
| Claude CVP + Mythos | 티어별 조건, 12/15 정적 키 금지, 실무 활용 | [한국어](claude-cvp-mythos/README.md) · [English](claude-cvp-mythos/README_en.md) |

## 문서 보안

| 주제 | 내용 | 문서 | 스크립트 |
| --- | --- | --- | --- |
| PDF 비식별화 | 검은 네모의 함정, 메타데이터 제거, CI 추출 게이트 | [한국어](pdf-redaction-ci/README.md) · [English](pdf-redaction-ci/README_en.md) | [check_pdf_redaction.sh](pdf-redaction-ci/check_pdf_redaction.sh) |

## 바로 쓰는 점검

```bash
# NFS2ROOT 노출 점검 (읽기 전용, CSV 집계)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/cve-2026-99362-nfs2root/check_nfs2root.sh
sudo bash check_nfs2root.sh --csv
```

```bash
# Java4Shell / NGINX2Shell 발동 조건 확인
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/java4shell-nginx2shell/check_java_nginx_exposure.sh
bash check_java_nginx_exposure.sh
```

```bash
# PDF 비식별화 CI 게이트 (poppler-utils 필요)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/pdf-redaction-ci/check_pdf_redaction.sh
bash check_pdf_redaction.sh document.pdf
```

```bash
# AWS Windows AMI · SSM Agent · DHMC 노출 점검 (읽기 전용)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/aws-ssm-agent-cve-2026-134069/audit_ssm_windows_ami.sh
bash audit_ssm_windows_ami.sh
```

```bash
# Traefik 버전 · access log 흔적 · gh CLI 버전 점검 (읽기 전용)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/traefik-cve-2026-137481-gh-cli/check_traefik_ghcli.sh
bash check_traefik_ghcli.sh --context prod
```

```bash
# Kyverno 버전 · 네임스페이스 Policy apiCall 노출 점검 (읽기 전용)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/kyverno-url-parser-ghsa-pcx2-xcq4-65vf/check_kyverno_parser.sh
bash check_kyverno_parser.sh --context prod
```

```bash
# GitHub · CI/CD 공급망 점검 (읽기 전용, gh CLI 로그인 필요)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/1password-github-breach/audit_github_cicd.sh
bash audit_github_cicd.sh ORG/REPO
```

```bash
# SYN queue · accept queue 점검 (읽기 전용, iproute2 필요)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/syn-flood-tcp-backlog/check_syn_backlog.sh
bash check_syn_backlog.sh --csv > syn_audit.csv
```

```bash
# SSRF 검증기 비교 (외부 요청 없음, 표준 라이브러리만)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/ssrf-url-parser-visual/safe_url_check.py
python3 safe_url_check.py
```

```bash
# AI 에이전트의 Workspace REST 직결 · Envoy 프록시 구성 점검 (읽기 전용)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/ai-agent-mcp-envoy-gateway/check_agent_gateway_usage.sh
bash check_agent_gateway_usage.sh --dir .
```

> 이 저장소의 문서와 스크립트는 점검 보조용입니다. 스크립트는 읽기 전용이며 시스템을 변경하지 않습니다. 벤더 권고와 조직 정책을 함께 확인하세요.
