# 가짜 Ollama BYOVD + K8s·Cloud Run MCP — 로컬 AI 도구의 기본값을 의심하라

[한국어](README.md) | [English](README_en.md)

가짜 한국어 Ollama 사이트(`ollama-ko.com`)에서 국내 백신을 무력화하는 악성코드가 유포됐습니다. 실행하면 공식 Ollama도 함께 설치돼 티가 나지 않고, 뒤에서는 정상 서명 드라이버로 커널에 들어가 백신 메모리를 변조합니다. 사내 K8s·Cloud Run MCP 서버도 같은 구조의 위험이 있습니다.

## 1. 가짜 Ollama — BYOVD

| 항목 | 내용 |
| --- | --- |
| 유포 도메인 | `ollama-ko.com` (공식은 `ollama.com`) |
| 수법 | BYOVD (Bring Your Own Vulnerable Driver) |
| 악용 드라이버 | `NeacSafe64.sys` — CVE-2025-45737, **1.0.0.8 미만** |
| 은폐 | 실행 시 공식 Ollama를 함께 설치 |
| 영향 | 백신 메모리 변조 |

### 점검

- 공식 주소 `ollama.com` 외의 한국어 위장 도메인 차단
- 의심 PC에서 `C:\Windows\System32:msedge.exe` **ADS(Alternate Data Stream)** 확인
- `NeacSafe64.sys` 존재·버전 확인
- 최신 AhnLab V3 / V3 Lite 예외·탐지 정책 확인

## 2. K8s MCP 서버 — 무인증 SSE

| 패키지 | 취약 버전 | CVE | 고정 |
| --- | --- | --- | --- |
| `k8s-mcp-server` | < 1.1.0 | CVE-2026-130007 | **>= 1.1.0** |
| `mcp-server-kubernetes` | < 4.2.0 | CVE-2026-134817 | **>= 4.2.0** |

- `k8s-mcp-server` 1.1.0 미만은 **`0.0.0.0:8080` 무인증 SSE가 기본값**입니다. 포트만 열려 있으면 클러스터 쓰기가 가능합니다.
- HTTP/SSE 사용 시 **`127.0.0.1` 바인딩 + `--read-only`** 강제 (가까운 시일 내 STDIO 전환 권장).

## 3. Cloud Run MCP — Google 11/20 사내 연동 표준

- 인그레스: `internal-only` + Egress Agent Gateway / PSC
- 이중 인증: `X-Serverless-Authorization`(IAM) + `Bearer`(OAuth 2.0)
- Private DNS: `*.run.app` 와일드카드 금지, **서비스 FQDN만** 피어링

## 오늘 바로 할 점검 3원칙

1. **가짜 Ollama 차단 & 바이너리 검증** — 도메인, ADS, `NeacSafe64.sys`
2. **K8s MCP 즉시 패치 & 바인딩 제한** — 버전 확인, `127.0.0.1`, `--read-only`
3. **Cloud Run MCP 연동 표준 적용** — internal-only, 이중 인증, FQDN 한정

> 로컬 LLM과 사내 MCP 모두 **'기본 설정(Default)'을 믿지 않는 것**이 시작입니다. 팀 내 Ollama 다운로드 경로와 MCP 포트 바인딩부터 확인하세요.

## 출처

- k8s-mcp-server advisory GHSA-m932-63jc-4jqq: https://github.com/reza-gholizade/k8s-mcp-server/security/advisories/GHSA-m932-63jc-4jqq
- Google — 내부 Cloud Run MCP를 Gemini Enterprise에 안전하게 연결: https://developers.googleblog.com/how-to-securely-connect-internal-cloud-run-mcp-servers-to-gemini-enterprise/

확인 기준일: 2026-11-26.
