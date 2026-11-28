# devsecops.kr

[한국어](README.md) | [English](README_en.md)

인스타그램 DevSecOps 매거진 [@devsecops.kr](https://www.instagram.com/devsecops.kr/) DM으로 보낸 자료와 점검 스크립트 모음입니다. DM으로 받은 링크는 이 저장소의 파일을 가리킵니다.

폴더를 주제별 컬렉션으로 묶었습니다. 원하는 주제를 눌러 들어가면 되고, 각 폴더는 한국어 `README.md`와 영어 `README_en.md`로 구성됩니다. 보도·벤더 공지 기준으로 정리했고 확인 기준일은 문서마다 표기했습니다. 패치 적용과 운영 판단은 소속 조직의 보안 정책을 따르세요.

**DM 키워드**는 게시물 캡션에 적힌 댓글 키워드입니다. 댓글에 키워드를 남기면 해당 자료 링크와 핵심 점검 항목을 DM으로 보냅니다.

## 최근 올라온 자료

| 날짜 | 주제 | DM 키워드 |
| --- | --- | --- |
| 11-28 | [한전 '저장은 암호문, 유출은 평문'](kepco-plaintext-exfiltration/README.md) — 암호키 유출 없이 복호화된 평문 65만 명분 | `PLAIN` |
| 11-28 | [국내 연쇄 해킹 4건](kr-breach-domino-2026-11-28/README.md) — 인터넷우체국·다나와·이나인페이·과기공제회 | `DOMINO` |
| 11-27 | [Traefik mTLS 헤더 우회](traefik-mtls-cve-2026-137480/README.md) — `Ssl-Client-*` 헤더 위조, 3.7.18 | `MTLS` |
| 11-27 | [Jenkins Script Security 샌드박스 탈출](jenkins-script-security-cve-2026-136835/README.md) — `@Builder` 컴파일 타임 실행 | `JENKINS` |
| 11-27 | [AI 에이전트 게이트웨이](ai-agent-mcp-envoy-gateway/README.md) — Workspace MCP 의무화와 ELB for Envoy | `MCP` |

## 컬렉션 바로가기

- [🚨 국내 보안사고 & 개인정보 유출](#kr-breach) — 7편
- [☸️ Kubernetes · 클라우드 · 네트워크](#k8s-cloud) — 13편
- [🔧 CI/CD · 공급망 · 런타임](#cicd) — 3편
- [🤖 AI 보안 · 실무 가이드](#ai-guide) — 9편
- [바로 쓰는 점검 스크립트](#quick) — 복사해서 실행하는 점검 명령

<a id="kr-breach"></a>
## 🚨 국내 보안사고 & 개인정보 유출

국내에서 확인된 유출·침해 사고와 그 사고에서 뽑은 방어 규칙입니다.

| 주제 | 핵심 한 줄 | DM 키워드 | 자료 |
| --- | --- | --- | --- |
| 2026년 11월 국내 유출 정리 | 금융권 37곳·한전·삼성증권·KICC·CJ올리브영·다나와·수협은행·호텔스토리까지, 반복해서 뚫린 외부 접점과 조회·대응 체크리스트 | `KR` `DOSSIER` `FIN` `KICC` `KEPCO` `SAMSUNG` `VOC` | [KR](korea-breach-tracker-2026-11/README.md) · [EN](korea-breach-tracker-2026-11/README_en.md) |
| 국내 연쇄 해킹 4건 (2026-11-28) | 인터넷우체국 하루치 11만 3,855명·다나와 유출 인정·이나인페이 90여 회 25억 원·과기공제회 21만 건, 조회 API 인가와 출금 통제 | `DOMINO` | [KR](kr-breach-domino-2026-11-28/README.md) · [EN](kr-breach-domino-2026-11-28/README_en.md) |
| 한전 — 저장은 암호문, 유출은 평문 | 암호키 유출·비인가 접근 없이 복호화된 평문이 나간 구조, Encryption at Rest로 못 막는 앱·API 복호화 계층, 응답 최소화·객체 인가 체크리스트 | `PLAIN` | [KR](kepco-plaintext-exfiltration/README.md) · [EN](kepco-plaintext-exfiltration/README_en.md) |
| CJ올리브영 업무시스템 침해 | 업무망 계정 침해로 790명 정보와 내부 관리용 회원번호 240만 6,338건 유출, 결제정보·비밀번호는 비노출 | `OLIVE` | [KR](cj-oliveyoung-breach/README.md) · [EN](cj-oliveyoung-breach/README_en.md) |
| 다나와 서비스 전면 중단 | 외부 침해 추정 사고로 웹·앱 15시간 이상 중단, 확인과 미확인을 나눈 이용자·운영팀 체크리스트 | `DANAWA` | [KR](danawa-service-outage/README.md) · [EN](danawa-service-outage/README_en.md) |
| 가상자산 거래소 연쇄 침해 | 빗썸 15일 침입 — 뚫린 곳은 콜드월렛이 아니라 그룹웨어·외주 상담사·핫월렛 | `CRYPTO` | [KR](crypto-exchange-breaches/README.md) · [EN](crypto-exchange-breaches/README_en.md) |
| 증권사 API 방어 룰북 | 7만 7,545명 유출 신고서에 적힌 세 구멍 — RFC 8693 인증변환, Redis HLL 레이트리밋, MyBatis `${}` 차단 | `SECURITIES` | [KR](securities-api-defense/README.md) · [EN](securities-api-defense/README_en.md) |

<a id="k8s-cloud"></a>
## ☸️ Kubernetes · 클라우드 · 네트워크

프록시·수신 컨트롤러·클러스터 정책부터 커널·로드밸런서까지, 인프라 계층에서 실제로 뚫리는 지점입니다.

| 주제 | 핵심 한 줄 | DM 키워드 | 자료 |
| --- | --- | --- | --- |
| Traefik Ingress NGINX mTLS 헤더 우회 (CVE-2026-137480) | 클라이언트 인증은 host 단위인데 `Ssl-Client-*` 헤더는 Ingress 단위로 계산 — `optional_no_ca` 이웃을 거쳐 `Ssl-Client-Verify: SUCCESS` 위조, 3.7.18·3.8.0-rc.2 | `MTLS` | [KR](traefik-mtls-cve-2026-137480/README.md) · [EN](traefik-mtls-cve-2026-137480/README_en.md) |
| Traefik 세미콜론 경로 인증 우회 (CVE-2026-137481) | `sanitizePath`가 남긴 `/..;x/`로 공개·보호 라우터가 같은 Java 백엔드를 공유하면 인증 미들웨어 우회, 2.11.62·3.7.18 | `TRAEFIK` | [KR](traefik-cve-2026-137481-gh-cli/README.md) · [EN](traefik-cve-2026-137481-gh-cli/README_en.md) |
| Kyverno apiCall URL 파서 불일치 (GHSA-pcx2-xcq4-65vf) | `?x=/namespaces/<ns>/` decoy가 검증을 통과하고 실행기는 `?` 뒤를 버려 클러스터 전역 자원과 타 네임스페이스 Secret 열람, 1.19.2 | `KYVERNO` | [KR](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README.md) · [EN](kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README_en.md) |
| AWS SSM Agent (CVE-2026-134069) | 2026-09-09 이전 AWS Windows AMI가 같은 SSM 등록 키를 공유, DHMC Role 자격증명 탈취, 인플레이스 패치 무효 | `SSM` | [KR](aws-ssm-agent-cve-2026-134069/README.md) · [EN](aws-ssm-agent-cve-2026-134069/README_en.md) |
| NFS2ROOT (CVE-2026-99362) | 리눅스 커널 `nfsd` 무인증 원격 루트 — AWS·EKS 해당 여부 판별과 고정 커널 버전 | `NFS` | [KR](cve-2026-99362-nfs2root/README.md) · [EN](cve-2026-99362-nfs2root/README_en.md) |
| Java4Shell · NGINX2Shell | OpenJDK AVX-512 VBMI RCE와 NGINX HTTP/2 RCE — CPU 명령어 집합과 프록시 설정이라는 발동 조건부터 확인 | `JAVA` | [KR](java4shell-nginx2shell/README.md) · [EN](java4shell-nginx2shell/README_en.md) |
| NGINX CVE-2026-132779 | TLS 1.3 `ssl_early_data` 환경에서 인증 없이 워커 CPU를 100%로 고정, 1.31.10·1.30.8 | `NGINX` | [KR](nginx-cve-2026-132779/README.md) · [EN](nginx-cve-2026-132779/README_en.md) |
| SSRF · URL 파서 불일치 | `?` 하나로 검증기와 클라이언트가 다른 목적지를 본다 — 우회 6종과 IMDSv2 hop limit 1 | `SSRF` | [KR](ssrf-url-parser-visual/README.md) · [EN](ssrf-url-parser-visual/README_en.md) |
| SYN Flood · TCP 백로그 | 회선이 아니라 대기열을 채우는 공격 — SYN queue·accept queue 구분과 커널 카운터 진단 | `SYN` | [KR](syn-flood-tcp-backlog/README.md) · [EN](syn-flood-tcp-backlog/README_en.md) |
| 클라우드 시크릿 연쇄 노출 | Rackspace Spot·Radware WAF·Azure APIM·Argo CD — IoC와 발급처 기준 키 로테이션 순서 | `SPOT` `SECRET` | [KR](cloud-secrets-exposure/README.md) · [EN](cloud-secrets-exposure/README_en.md) |
| AWS 로컬 에뮬레이터 | `aws/aws-emulator` 438개 API 모델 — 로컬 테스트 통과가 운영 배포 안전을 뜻하지 않는 IAM·KMS·텔레메트리 제약 | `AWS` | [KR](aws-emulator/README.md) · [EN](aws-emulator/README_en.md) |
| Lambda 30분 타임아웃 | `--timeout 1800`만 올리면 동시성·SQS Visibility·NAT Keep-Alive에서 나는 6가지 함정 | `LAMBDA` | [KR](lambda-30min-timeout/README.md) · [EN](lambda-30min-timeout/README_en.md) |
| VMware VMSA-2026-0011 | vCenter 인증 우회(CVSS 9.8)와 ESX I/O 필터 RCE — 지난주 제로데이 패치와 별개라 다시 확인 | `VMWARE` | [KR](vmware-vmsa-2026-0011/README.md) · [EN](vmware-vmsa-2026-0011/README_en.md) |

<a id="cicd"></a>
## 🔧 CI/CD · 공급망 · 런타임

빌드 파이프라인과 개발자 계정, 배포 자격증명에서 시작하는 침해입니다.

| 주제 | 핵심 한 줄 | DM 키워드 | 자료 |
| --- | --- | --- | --- |
| 1Password GitHub 계정 침해 | 직원 기업 GitHub 계정 하나에서 비공개 소스 복사·CI/CD 접근·백엔드 악성코드까지, 4대 통제(Classic PAT 금지·CODEOWNERS·OIDC·복구 코드 관리) | `1PASS` | [KR](1password-github-breach/README.md) · [EN](1password-github-breach/README_en.md) |
| Jenkins Script Security `@Builder` 샌드박스 탈출 (CVE-2026-136835) | 샌드박스가 씌워지기 전 컴파일 단계에서 임의 클래스 생성자 실행 — script-security `1436.1438.v3dc5ef7d16f2`·코어 2.479.3+ | `JENKINS` | [KR](jenkins-script-security-cve-2026-136835/README.md) · [EN](jenkins-script-security-cve-2026-136835/README_en.md) |
| GitHub Actions OIDC vs 정적 키 | 무기한 `AKIA` 키 대신 `sub`·`aud`를 확인하는 15분~1시간 STS 자격증명, 전환·폐기 순서와 흔한 함정 | `OIDC` | [KR](github-oidc-vs-static-key/README.md) · [EN](github-oidc-vs-static-key/README_en.md) |

> GitHub CLI 2.106.0 보안 7건은 [Traefik 세미콜론 경로 인증 우회](traefik-cve-2026-137481-gh-cli/README.md) 폴더에 함께 정리돼 있습니다.

<a id="ai-guide"></a>
## 🤖 AI 보안 · 실무 가이드

에이전트를 쓰는 쪽과 막는 쪽 모두의 자료, 그리고 문서·데이터를 다루는 실무 가이드입니다.

### AI 보안

| 주제 | 핵심 한 줄 | DM 키워드 | 자료 |
| --- | --- | --- | --- |
| AI 에이전트 게이트웨이 | Google Workspace REST 직결 제한(2027-02-01)과 AWS ELB for Envoy GA — 검사와 패치를 단일 관문으로 모으는 두 발표 | `MCP` | [KR](ai-agent-mcp-envoy-gateway/README.md) · [EN](ai-agent-mcp-envoy-gateway/README_en.md) |
| AI 에이전트 주도 침해 | EU 집행위·국내 대학·금융·외교에서 정찰·침투·웹 변조를 자동화한 사고, ARTEX/Storm-0940/KimJEN | `AI` | [KR](ai-agent-attacks/README.md) · [EN](ai-agent-attacks/README_en.md) |
| 보안팀 AI 에이전트 6선 | Red/Blue 팀별 오픈소스 비교와 사내 도입 가드레일 | `AGENT` | [KR](ai-security-agents/README.md) · [EN](ai-security-agents/README_en.md) |
| Claude CVP + Mythos | 방어 목적 보안팀의 가드레일 완화 승인 프로그램, 티어 조건과 12/15 정적 키 금지 | `CVP` | [KR](claude-cvp-mythos/README.md) · [EN](claude-cvp-mythos/README_en.md) |
| AI 에이전트 샌드박스 | AWS Nitro Sandboxes vs Google Agent CE — 컨테이너 격리를 넘는 하드웨어 격리와 NSM PCR 키 정책 | `SANDBOX` | [KR](agent-sandboxes/README.md) · [EN](agent-sandboxes/README_en.md) |
| OpenShell (CNCF) | 에이전트를 OS 커널 수준에서 격리하는 오픈소스 런타임, 0.1.x 한계 | `OPEN` | [KR](openshell-cncf/README.md) · [EN](openshell-cncf/README_en.md) |
| 가짜 Ollama BYOVD + MCP | 가짜 한국어 Ollama 사이트의 백신 무력화 드라이버와 무인증 SSE MCP 서버 패치 | `OLLAMA` | [KR](fake-ollama-byovd-mcp/README.md) · [EN](fake-ollama-byovd-mcp/README_en.md) |
| OpenRouter 프롬프트 탈취 | ZDR은 첫 번째 홉만 지킨다 — 업스트림 추론 제공자 점검과 토큰 로테이션 | `OPENROUTER` | [KR](openrouter-prompt-theft/README.md) · [EN](openrouter-prompt-theft/README_en.md) |

### 실무 가이드

| 주제 | 핵심 한 줄 | DM 키워드 | 자료 |
| --- | --- | --- | --- |
| PDF 비식별화 | 검은 네모는 삭제가 아니다 — 판결문 10건 230명분 개인정보가 복원된 이유, 메타데이터 제거와 CI 추출 게이트 | `PDF` | [KR](pdf-redaction-ci/README.md) · [EN](pdf-redaction-ci/README_en.md) |

<a id="quick"></a>
## 바로 쓰는 점검

모든 스크립트는 읽기 전용이며 시스템을 변경하지 않습니다.

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
# Traefik mTLS host · Ingress 어노테이션 · 헤더 제거 점검 (읽기 전용)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/traefik-mtls-cve-2026-137480/check_traefik_mtls.sh
bash check_traefik_mtls.sh --context prod
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

```bash
# Jenkins Script Security 샌드박스 탈출(CVE-2026-136835) 노출 점검 (읽기 전용)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/jenkins-script-security-cve-2026-136835/check_jenkins_script_security.sh
bash check_jenkins_script_security.sh --url "$JENKINS_URL" --user bot --token "$TOKEN" --jenkins-home /var/lib/jenkins
```

> 이 저장소의 문서와 스크립트는 점검 보조용입니다. 벤더 권고와 조직 정책을 함께 확인하세요.
