# SSRF — URL 파서 불일치로 뚫리는 내부망 (기술 시각화 01)

[한국어](README.md) | [English](README_en.md)

`https://169.254.169.254/?from=api.trusted.com` — 문자열 검사는 `trusted.com`을 보고 통과시키고, HTTP 클라이언트는 호스트를 `169.254.169.254`로 읽습니다. SSRF(Server-Side Request Forgery)는 취약한 API 하나의 문제가 아니라 **검증하는 코드와 실제로 연결하는 코드가 같은 문자열을 다르게 해석하는 문제**입니다.

이 문서는 릴스 「기술 시각화 01」의 원문 정리입니다. 파서가 갈라지는 지점, 표기만 바꾸는 우회 6종, 그리고 IMDSv2 `hop limit 1`을 포함한 방어 4원칙을 담았습니다. 점검용 페이로드 목록은 [`ssrf_payloads.txt`](ssrf_payloads.txt), 같은 파서로 검증하는 예제 코드는 [`safe_url_check.py`](safe_url_check.py)에 있습니다.

## 한눈에

| 항목 | 내용 |
| --- | --- |
| 분류 | CWE-918 Server-Side Request Forgery |
| 근본 원인 | 검증기와 HTTP 클라이언트의 **URL 파서 불일치**(파일 경로 함수·부분 문자열 검사 vs RFC 3986 파서) |
| 대표 목적지 | `169.254.169.254`(클라우드 IMDS), `10.96.0.1`(K8s API Service), `127.0.0.1`, 내부 Redis·관리 포트 |
| 한 요청의 결과 | 공개 API 호출 → IMDS 조회 → 임시 자격증명 회수 (릴스 기준 0.42초, 실측값이 아니라 순서) |
| 우회 변형 | `@` userinfo · 10진수/16진수 IP · IPv6 매핑 · 302 리다이렉트 · fragment (`#@`) |
| 점검 자료 | [`ssrf_payloads.txt`](ssrf_payloads.txt) · [`safe_url_check.py`](safe_url_check.py) |
| 핵심 방어 | ① 파싱은 한 번, 검증과 요청이 같은 결과 ② host 완전 일치 + DNS 후 IP 검사 ③ 리다이렉트 차단 · IMDSv2 ④ 이그레스 allowlist |

> 이 문서의 시나리오는 공개된 표준(RFC 3986)과 클라우드 문서 기준으로 재구성한 것입니다. 특정 서비스의 실제 침해 사례를 인용하지 않습니다.

## 1. 무슨 문제인가

SSRF가 성립하려면 두 가지가 같이 있어야 합니다.

1. **사용자가 목적지의 일부를 정할 수 있다** — URL, 콜백 주소, 이미지·PDF 가져오기, 웹훅, 프록시, 링크 미리보기 등.
2. **그 요청이 서버의 신뢰 경계 안에서 나간다** — 서버는 내부망·메타데이터 엔드포인트에 닿을 수 있고, 사용자는 직접 닿을 수 없습니다.

그래서 방어는 대개 "허용 목록(allowlist)"으로 시작합니다. 문제는 그 허용 목록을 **문자열로** 검사할 때 생깁니다.

```python
if "trusted.com" in url:      # 검증기: 문자열 안에 있으면 통과
    requests.get(url)          # 클라이언트: URL을 파싱해 host로 접속
```

`https://169.254.169.254/?from=api.trusted.com`은 두 문장을 모두 만족합니다. 검증기는 `query`까지 읽어 `trusted.com`을 찾아내고, 클라이언트는 `authority`만 읽어 `169.254.169.254`로 접속합니다. **같은 문자열, 다른 목적지**입니다.

## 2. Root Cause — 어디서 갈라지는가

### 2-1. `?` 앞뒤로 역할이 다르다

RFC 3986의 URL 구조는 `scheme://authority/path?query#fragment`입니다.

| 구간 | 검증기가 보는 것 | 클라이언트가 쓰는 것 |
| --- | --- | --- |
| `https://169.254.169.254/` | 문자열의 일부 | **host** — 실제 연결 대상 |
| `?from=api.trusted.com` | `trusted.com`이 들어 있다 → 허용 | **query** — 서버로 전달되는 파라미터 |
| `#@169.254.169.254` | 문자열의 일부 | **fragment** — 서버로 전송되지 않음 |

검사는 "문자열 전체"에서 하고, 연결은 "authority"에서 합니다. 이 간극이 SSRF의 절반입니다.

### 2-2. 파서를 섞으면 더 나빠진다

`?`를 특별하게 보지 않는 함수로 검증하면 문제가 커집니다.

| 검증에 쓴 함수 | `?` 처리 | 결과 |
| --- | --- | --- |
| 부분 문자열 검사 (`in`, `startswith`) | 의미 없음 | query에 든 문자열도 통과 |
| 파일 경로 정규화 (`path.Clean`, `posixpath.normpath`) | 일반 문자 | 정규식·접두사 비교를 통과 |
| URL 파서 (`net/url`, `urllib.parse.urlsplit`) | query 시작 | host를 정확히 분리 |

Kyverno `apiCall` 사례(`GHSA-pcx2-xcq4-65vf`)도 같은 뿌리입니다 — 검증은 `path.Clean`, 실행은 `net/url`. 이 저장소의 [`kyverno-url-parser-ghsa-pcx2-xcq4-65vf`](../kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README.md)에서 같은 원리를 쿠버네티스 맥락으로 더 자세히 다룹니다.

### 2-3. 검증 후 다시 해석하면 끝나지 않는다 (TOCTOU)

검증 시점과 요청 시점 사이에 값이 달라지면 같은 문제가 반복됩니다.

- **DNS 리바인딩**: 검증 시점에는 공인 IP로 해석되고, 요청 시점에는 `127.0.0.1`로 해석되는 도메인.
- **리다이렉트**: 허용된 호스트가 `302`로 내부 주소를 가리킨다.
- **정규화 차이**: 퍼센트 인코딩·대소문자·후행 점(`169.254.169.254.`)·유니코드.

그래서 방어의 첫 문장은 "검사한 그 값으로 요청한다"입니다. 문자열을 다시 넘기지 말고, **파싱 결과(host, port, path, query)를 그대로** 클라이언트에 넘깁니다.

## 3. 공격 흐름 — 공격자는 내부 요청을 위조하지 않는다

```
사용자 입력 URL
   └─ 검증기 (allowlist 통과)
        └─ HTTP 클라이언트 → 169.254.169.254 (IMDS)
             └─ 임시 자격증명 회수 → 클라우드 API
```

1. **0.00s** 공개 API 호출 (정상 사용자처럼 보이는 요청)
2. **0.21s** 서버가 IMDS를 조회 (`/latest/meta-data/iam/security-credentials/`)
3. **0.42s** 자격증명이 응답 본문이나 에러 메시지에 실려 나감

숫자는 릴스의 연출값이며 실측 시간이 아니라 **순서**를 보여줍니다. 실제로는 응답을 그대로 돌려주지 않는 서버도 많고, 그때는 블라인드 SSRF로 내부 포트·서비스 탐색에 쓰입니다.

도달 가능한 대표 목적지:

| 목적지 | 주소 | 비고 |
| --- | --- | --- |
| AWS IMDS | `169.254.169.254` (IPv6 `fd00:ec2::254`) | IMDSv1은 토큰 없이 GET |
| ECS 태스크 자격증명 · IRSA | `169.254.170.2` | 컨테이너 전용 엔드포인트 |
| EKS Pod Identity | `169.254.170.23` | 파드 단위 자격증명 |
| GCP 메타데이터 | `metadata.google.internal` / `169.254.169.254` | `Metadata-Flavor: Google` 헤더 필요 |
| Azure IMDS | `169.254.169.254` | `Metadata: true` 헤더 필요 |
| Kubernetes API | `10.96.0.1` (Service), `kubernetes.default.svc` | 파드 SA 토큰과 결합 시 권한 상승 |
| 로컬 서비스 | `127.0.0.1:6379`(Redis), `:2375`(docker.sock TCP), `:8080`(admin) | 인증 없는 내부 포트 |

> GCP·Azure는 필수 헤더가 있어 단순 GET으로는 응답을 못 받습니다. 다만 **헤더를 붙일 수 있는 SSRF**(프록시형·헤더 주입 가능형)라면 이야기가 달라지므로, 헤더 요구를 방어선으로 세지 마세요.

## 4. 우회 변형 6종

같은 목적지, 다른 표기. 허용 목록이 문자열 기반이면 아래 중 하나는 통과합니다.

| # | 페이로드 | 무엇을 하는가 | 통과하는 검증기 |
| --- | --- | --- | --- |
| ① | `https://api.trusted.com@169.254.169.254/` | `@` 앞은 userinfo, 뒤가 host | `@` 앞 도메인을 보는 검사 |
| ② | `http://2852039166/` | `2852039166` = `169.254.169.254`의 10진수 표기 | 점(`.`) 4개 형식을 기대하는 정규식 |
| ③ | `http://0xA9FEA9FE/` | 같은 주소의 16진수 표기 | 10진수만 막는 규칙 |
| ④ | `http://[::ffff:a9fe:a9fe]/` | IPv4-mapped IPv6 표기 | IPv4 대역만 차단하는 규칙 |
| ⑤ | `https://api.trusted.com/redirect?to=169.254.169.254` | 허용 호스트가 `302`로 내부 주소를 가리킴 | 최초 목적지만 검사하고 리다이렉트를 따라감 |
| ⑥ | `https://169.254.169.254/#@api.trusted.com` | fragment는 서버로 전송되지 않음 | `#` 뒤까지 문자열로 검사 |

추가로 자주 쓰이는 계열(같은 원리의 확장):

- **후행 점·대소문자**: `169.254.169.254.`, `LOCALHOST`, `127.1`, `0x7f.1`
- **퍼센트 인코딩**: `169.254.169.254%2f`, `%31%36%39.254.169.254`
- **DNS 리바인딩**: 첫 해석은 공인 IP, 두 번째 해석은 사설 IP
- **8진수·혼합 표기**: `0251.0376.0251.0376`
- **와일드카드 DNS**: `169.254.169.254.nip.io` 같은 서비스가 IP를 호스트명으로 감쌈

`[::ffff:...]` 같은 IPv6 표기와 `@` userinfo는 라이브러리별 허용 동작이 다릅니다. 검증할 때는 **"우리 스택의 클라이언트가 실제로 어떤 host로 연결하는가"**를 기준으로 확인해야 합니다. `ssrf_payloads.txt`의 각 항목에 어떤 검사가 뚫리는지 적어 두었습니다.

## 5. 방어 4원칙

### ① 파싱은 한 번, 그 결과로 요청한다

```python
from urllib.parse import urlsplit

parts = urlsplit(raw)                 # 1회 파싱
host = (parts.hostname or "").lower() # 이후 이 값만 사용
# 검증도, 요청 구성도 host·port·path 로만 한다
```

`requests.get(raw)`처럼 원본 문자열을 다시 넘기면 라이브러리가 재해석합니다. 그 순간 검증과 실행이 다시 갈라집니다.

### ② host 완전 일치 + DNS 후 IP 검사

- 허용 목록은 **완전 일치**(`api.trusted.com`) 또는 **명시적 서브도메인 규칙**(`.trusted.com` 끝 + 라벨 경계)으로 비교합니다. `in`, `startswith("api.")` 같은 부분 비교는 쓰지 않습니다.
- 이름이 맞아도 **해석된 IP를 검사**합니다. `ipaddress`로 아래 대역을 모두 거부합니다.

```text
0.0.0.0/8  10.0.0.0/8  100.64.0.0/10  127.0.0.0/8  169.254.0.0/16
172.16.0.0/12  192.168.0.0/16  198.18.0.0/15  224.0.0.0/4  240.0.0.0/4
::1/128  fc00::/7  fe80::/10  ::ffff:0:0/96
```

- 해석 결과가 여러 개면 **전부** 검사합니다. 하나라도 거부 대역이면 실패로 처리합니다.

### ③ 리다이렉트 차단 · IMDSv2 `hop limit 1`

- HTTP 클라이언트에서 **리다이렉트를 끄거나**, 따라갈 때마다 같은 검증을 다시 적용합니다(`allow_redirects=False`, `max_redirects=0`).
- 클라우드 쪽에서 한 겹 더 막습니다. AWS IMDSv2는 토큰(PUT)을 먼저 받아야 하고, `http-put-response-hop-limit`을 **1**로 두면 컨테이너·프록시 한 홉을 건너는 요청이 IMDS에 닿지 못합니다.

```bash
# 인스턴스 단위 (읽기 전용 확인 → 변경은 정책 승인 후)
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{id:InstanceId,imds:MetadataOptions}' --output table

# 변경 예시: 토큰 필수 + hop limit 1
aws ec2 modify-instance-metadata-options \
  --instance-id i-0123456789abcdef0 \
  --http-tokens required --http-put-response-hop-limit 1
```

> `hop limit 1`은 **파드가 IMDS를 직접 부르는 구조를 끊습니다**. IRSA·EKS Pod Identity처럼 별도 엔드포인트(`169.254.170.2`, `169.254.170.23`)를 쓰는 방식은 영향이 없으므로, 권한이 필요한 파드는 그쪽으로 옮기는 것이 정석입니다. 기존 애플리케이션이 IMDSv1을 직접 호출하고 있다면 먼저 SDK·IRSA 전환 후에 조입니다.

### ④ 이그레스 allowlist — 코드가 아니라 네트워크에서

애플리케이션 검증은 코드가 하나만 빠져도 뚫립니다. 최종 방어선은 네트워크 계층입니다.

- Security Group·NACL·NetworkPolicy로 **목적지 CIDR·포트를 제한**하고, `169.254.0.0/16`·클러스터 CIDR·메타데이터 주소로의 아웃바운드를 기본 거부합니다.
- 프록시를 경유시키는 구조라면 프록시에서 **host 기준 allowlist + 사설 대역 거부**를 강제합니다.
- 서버리스·관리형 런타임도 VPC 아웃바운드 정책과 메타데이터 옵션을 같은 기준으로 맞춥니다.

## 6. 발동 조건

| 조건 | 설명 |
| --- | --- |
| 사용자 입력이 목적지 일부가 됨 | URL·콜백·이미지/PDF fetch·웹훅·미리보기·번역·프록시 |
| 서버가 내부망·메타데이터에 도달 가능 | 기본값이 대개 그렇습니다 |
| 검증이 문자열 기반이거나 파서가 다름 | `in`, `startswith`, `path.Clean`, 정규식 접두사 비교 |
| 응답이 사용자에게 반환되거나 에러에 포함 | 없으면 블라인드 SSRF(탐색·부작용 유발)로 축소 |

### 해당 없음 / 위험 낮음

- **목적지가 코드에 고정**된 경우(사용자는 파라미터만) — 신뢰 경계가 열리지 않습니다.
- **이그레스가 화이트리스트로 닫힌** 환경 — SSRF는 성립해도 도달할 곳이 없습니다.
- **IMDSv2 전용 + hop limit 1** — 자격증명 회수 경로가 막힙니다(내부 서비스 탐색은 남음).

## 7. 점검

### 7-1. 코드에서 찾기

```bash
# 문자열 기반 URL 검사 (SSRF 1차 후보)
grep -rnE '"(trusted|allowed)[^"]*"\s+in\s+|startswith\(["'"'"']https?://|\.hostname\s*==|path\.Clean|normpath' \
  --include='*.py' --include='*.go' --include='*.js' --include='*.ts' .
```

확인할 것:

- [ ] 검증에 쓴 값과 요청에 쓴 값이 **같은 파싱 결과**인가
- [ ] 허용 목록이 **완전 일치**인가 (`in`, 접두사 비교 아님)
- [ ] DNS 해석 후 **IP 대역 검사**가 있는가
- [ ] 리다이렉트를 따라가는가 (`allow_redirects` 기본값 확인)
- [ ] 에러·로그에 내부 응답 본문이 실려 나가는가

### 7-2. 예제 코드 실행

[`safe_url_check.py`](safe_url_check.py)는 의존성 없는 예제입니다. 같은 URL을 ①문자열 검사 ②`urlsplit` 파싱 ③IP 대역 검사에 통과시켜 **어느 검사가 어디서 뚫리는지** 표로 보여줍니다. 외부로 요청을 보내지 않습니다.

```bash
python3 safe_url_check.py
```

```
# 실제 출력 (2026-11-27, Python 3)
payload                                         substr   parse    ipcheck  verdict
https://api.trusted.com/health                  PASS     PASS     PASS     ALLOW
https://169.254.169.254/?from=api.trusted.com   PASS     FAIL     FAIL     BLOCK (host mismatch)
https://api.trusted.com@169.254.169.254/        PASS     FAIL     FAIL     BLOCK (userinfo)
http://2852039166/                              FAIL     FAIL     FAIL     BLOCK (host mismatch)
http://0xA9FEA9FE/                              FAIL     FAIL     FAIL     BLOCK (host mismatch)
http://[::ffff:a9fe:a9fe]/                      FAIL     FAIL     FAIL     BLOCK (host mismatch)
https://169.254.169.254/#@api.trusted.com       PASS     FAIL     FAIL     BLOCK (host mismatch)
https://api.trusted.com./health                 PASS     PASS     PASS     ALLOW
file:///etc/passwd                              FAIL     FAIL     FAIL     BLOCK (scheme)
https://api.trusted.com\@169.254.169.254/       PASS     FAIL     FAIL     BLOCK (backslash)

자체 검증 통과: 10건 — 문자열 검사만으로는 4건이 통과한다
```

`substr` 열이 `PASS`인데 최종 `BLOCK`인 4건이 이 문서의 요점입니다. 같은 4건이 **부분 문자열 검사만 있는 코드에서는 전부 통과**합니다.

### 7-3. 페이로드 목록

[`ssrf_payloads.txt`](ssrf_payloads.txt)는 위 변형을 그대로 담았습니다. 스테이징 환경의 **자사 엔드포인트에만** 사용하세요. 외부 서비스에 대한 무단 시험은 법적 문제가 됩니다.

## 8. 2분 요약

- SSRF의 핵심은 **검증기와 클라이언트가 같은 문자열을 다르게 읽는 것**입니다. `?` 뒤는 검사에는 보이고, 연결에는 쓰이지 않습니다.
- 표기만 바꿔도 통과합니다 — `@` userinfo, 10진수·16진수 IP, IPv6 매핑, 302, fragment.
- 방어는 **파싱 1회 → 완전 일치 → IP 대역 검사 → 리다이렉트 차단 → IMDSv2 hop limit 1 → 이그레스 allowlist** 순서로 겹칩니다.
- 오늘 코드에서 볼 한 줄: **"host 검증이 문자열 비교인가, 파싱 결과 비교인가."**

## 출처

- RFC 3986 — Uniform Resource Identifier (URI): Generic Syntax (§3.2 authority): https://www.rfc-editor.org/rfc/rfc3986#section-3.2
- OWASP — Server-Side Request Forgery Prevention Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html
- AWS — Use the Instance Metadata Service (IMDSv2, hop limit): https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html
- AWS — ECS 태스크 자격증명 엔드포인트(`169.254.170.2`): https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
- AWS — EKS Pod Identity(`169.254.170.23`): https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- Google Cloud — Metadata server: https://cloud.google.com/compute/docs/metadata/overview
- Microsoft — Azure Instance Metadata Service: https://learn.microsoft.com/en-us/azure/virtual-machines/instance-metadata-service

확인 기준일: 2026-11-27. 클라우드 메타데이터 엔드포인트 주소·기본 hop limit 값은 리전·런타임·생성 시점에 따라 달라질 수 있으므로, 적용 전에 해당 서비스 문서를 함께 확인하세요.
