# GHSA-pcx2-xcq4-65vf — Kyverno `apiCall` namespace isolation bypass via a URL parser differential

[한국어](README.md) | [English](README_en.md)

A single `?` broke Kyverno's namespace isolation. A tenant confined to one namespace can put `/api/v1/nodes?x=/namespaces/default/` in an `apiCall` `urlPath`: the **validator sees the `/namespaces/default/` inside the query and passes it**, while **the executor (client-go) cuts everything after `?` and requests the cluster-scoped `/api/v1/nodes`**. The tenant ends up reading Secrets in other namespaces and cluster-scoped resources with Kyverno's privileges.

The point is not the score but that **two different parsers read the same string**. Go's `path.Clean` is built for file paths and does not treat `?` as special; `net/url` treats it as the start of a query. That mismatch is the gap between validation and execution. **Kyverno 1.19.2** is the fixed release, and [`check_kyverno_parser.sh`](check_kyverno_parser.sh) reports exposure read-only.

## At a glance

| Item | Detail |
| --- | --- |
| GitHub Advisory | GHSA-pcx2-xcq4-65vf (Critical), published 2026-10-21 |
| CVE | CVE-2026-122312 |
| Weakness | CWE-269 Improper Privilege Management · CWE-918 Server-Side Request Forgery |
| CVSS | **10.0** as published by Akamai · v4 **8.3** in the CVE record (`AV:N/AC:L/AT:N/PR:L/UI:N/VC:H/VI:N/VA:N/SC:H/SI:N/SA:N`) |
| Affected | Kyverno **< 1.19.2** (GitHub Advisory). The CVE/Bitnami record narrows it to **1.19.1 ≤ x < 1.19.2** |
| Fixed | **Kyverno 1.19.2** — PR #17984, commit `f67231def576eb0ad153dd8cbfc836908ab14c14` |
| Reported | Akamai Security Group, reported 2026-09-03, advisory 2026-10-21, analysis 2026-11-24 |
| Exposure | **4%** of enterprise networks ran a vulnerable Kyverno per Akamai telemetry |
| Preconditions | Tenant can **create a namespaced `Policy` with `apiCall`** + Kyverno's admission SA keeps its default broad RBAC |
| Check | [check_kyverno_parser.sh](check_kyverno_parser.sh) · validator comparison [url_validator_example.py](url_validator_example.py) |

> **Why two CVSS numbers**: Akamai reported and published GHSA-pcx2-xcq4-65vf as CVSS 10.0; the later CVE-2026-122312 record (Bitnami/OSV, VulnCheck) lists CVSS v4 8.3. GitHub's own severity is Critical. When quoting a score in a report, **name the source of the score**.

## 1. What the flaw is

Kyverno is a cluster-wide admission controller. It has to inspect requests in every namespace, so its admission controller ServiceAccount holds cluster-wide read permissions by default. That design is normal — and it means **anyone who can author a policy can borrow Kyverno's authority**.

`apiCall` is a legitimate feature: a policy fetches external data from the Kubernetes API to make a decision. The canonical example is a policy that reads an "allowed images" ConfigMap and checks a Pod's image against it.

The problem is the restriction that keeps a **namespaced `Policy`** from reaching outside its own namespace through `apiCall`. That restriction arrived with CVE-2026-22039 (January 2026), and GHSA-pcx2-xcq4-65vf is **a way around it**.

- The attacker holds a low privilege (create a Policy in their own namespace).
- Kyverno holds a high privilege (cluster-wide read).
- The attacker makes Kyverno read what they cannot → a textbook **confused deputy**.

## 2. Root cause — the validator reads a file path, the executor reads a URL

`Fetch()` in `pkg/engine/apicall/apiCall.go` (lines 68–106 at the time) ran `URLPath` through `url.PathUnescape` and `path.Clean`, then matched a regex to extract the namespace and compare it with the policy's namespace.

```go
var namespacePathRegex = regexp.MustCompile(`^/api(s)?/.*?/namespaces/([^/]+)/?.*$`)
```

`path.Clean` is a **file path** function. In a file name `?` carries no special meaning, so it survives unchanged. The HTTP layer, client-go, parses the same string with `net/url` and splits the query off at `?`.

### What the validator sees

Input: `/api/v1/nodes?x=/namespaces/default/`

1. `url.PathUnescape` — nothing to decode, unchanged
2. `path.Clean` — `/api/v1/nodes?x=/namespaces/default` (the `?` is kept as a path character; only the trailing slash goes)
3. `namespacePathRegex` — the lazy `.*?` swallows `v1/nodes?x=`, then `/namespaces/` matches literally and `([^/]+)` captures **`default`**
4. The policy lives in `default`, so **validation passes**

### What the executor sends

1. The execution path receives the **original, uncleaned** `call.APICall.URLPath`: `executor.Execute()` → `executeK8sAPICall()` → `client.RawAbsPath()` → `c.rest.Get().RequestURI(path)`
2. `RequestURI` parses it with `net/url` → Path `/api/v1/nodes`, Query `x=/namespaces/default/`
3. Actual request: **`GET /api/v1/nodes`** — a cluster-scoped resource

The Kubernetes API server routes on the **path only** and ignores unknown query parameters, so the namespace the validator approved and the resource actually reached have nothing to do with each other.

### The deeper problem: validation and execution use different values (TOCTOU-shaped)

Fixing query strings alone would leave the structure intact: **validation runs on `cleanPath`, execution runs on the original `URLPath`**. As long as two representations of the same input are in play, the next bypass is a matter of time. The fix introduces `canonicalizeURLPath()`, which splits path, query and fragment with `net/url` **before** decoding and cleaning, rejects fragments and absolute URLs, cleans only the path, and makes **validation and execution share that single canonical value**. (Execution still sends path+query so legitimate parameters such as `labelSelector` keep working; the namespace clamp is matched against the cleaned path only.)

The earlier hardening commit `7ac176ac8` (GHSA-c5qq-7g2q-cpqp and others) closed percent-encoded path traversal but **not query string injection**. This advisory is that gap.

## 3. How the attack runs — exfiltration through the denial message

Reading data is useless if the policy simply passes and the attacker never sees the result. So the attacker writes a policy that **always fails** and **interpolates the fetched data into the deny message**.

1. The tenant creates a `Policy` in its own namespace with a decoy in `context.apiCall.urlPath`.
2. `validate.message` contains `{{ leakedData }}`, and `deny: {}` makes the rule always deny.
3. When the attacker creates a matching resource (a ConfigMap, say), the admission webhook returns the denial, and **the fetched ConfigMap content rides along inside that message** back to the attacker.

```yaml
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: cross-ns-leak
  namespace: default            # the tenant namespace
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

The response from the advisory's PoC:

```
Error from server: error when creating "STDIN": admission webhook "validate.kyverno.svc-fail" denied the request:
cross-ns-leak:
  leak-config: 'LEAKED DATA: {"key":"confidential-data"}'
```

The request was blocked, but the data had already left. **A denial response is still an exfiltration channel** — that is the practical lesson of this incident.

## 4. Variants

The same trick generalises to any cluster-scoped or cross-namespace resource. The first four rows are from the advisory; the last is the same family, confirmed by the fix rejecting fragments.

| Malicious `urlPath` | Namespace the validator sees | Actual request path |
| --- | --- | --- |
| `/api/v1/nodes?x=/namespaces/default/` | `default` | `/api/v1/nodes` (cluster-scoped) |
| `/api/v1/secrets?x=/namespaces/default/` | `default` | `/api/v1/secrets` (all namespaces) |
| `/apis/rbac.authorization.k8s.io/v1/clusterroles?x=/namespaces/default/` | `default` | `/apis/.../clusterroles` |
| `/api/v1/namespaces/kube-system/secrets?x=/namespaces/default/` | `default` ※ | `/api/v1/namespaces/kube-system/secrets` |
| `/api/v1/secrets#/namespaces/default/` | `default` | `/api/v1/secrets` (fragment never sent) |

> **※ Reproduction note — row 4 does not pass validation as written.** The `.*?` in the regex is lazy, so it captures the **first** `/namespaces/` in the string. In `/api/v1/namespaces/kube-system/secrets?...` that is `kube-system`, and validation rejects it. Real cross-namespace reads use **cluster-wide collection endpoints** with no namespace in the path (`/api/v1/secrets`, `/api/v1/configmaps`). Case 4 in [`url_validator_example.py`](url_validator_example.py) shows exactly this. It is the most commonly mis-copied row of the advisory table.

**It is not only reads.** The fix commit notes that the same query decoy with `POST` could create a cluster-wide `MutatingWebhookConfiguration`; that outcome is tracked separately as CVE-2026-100706. Blocking read APIs alone does not close this class.

## 5. Three traps that bite web applications the same way

Kyverno is Go, but the same mistakes live in ordinary web backends. Check for them in your own code.

### ① `posixpath.normpath` + `requests`

`normpath` is a file path function: it treats `?` and `#` as ordinary characters. `requests`/urllib3 parses the same string as a URL and sends the query separately. Validation inspects A, the request goes to B.

```python
import posixpath, requests
path = f"/internal/{user_input}"
safe = posixpath.normpath(path).startswith("/internal/")   # blind to '?'
requests.get("http://api.internal" + path)                  # everything after '?' becomes the query
```

### ② `?next=` open redirect — browsers and `urlsplit` disagree

For special schemes the browser (WHATWG URL) **normalises a backslash `\` to `/`**; Python's `urlsplit` follows RFC 3986. The validator sees one host and the browser visits another.

| Input | `urlsplit().hostname` | Where the browser actually goes |
| --- | --- | --- |
| `https://evil.com\@good.com/` | `good.com` (allowed) | `evil.com` |
| `/\evil.com` | none (a `path`), passes a "starts with `/`" check | `//evil.com` → `evil.com` |

Validation rules: reject any backslash; reject a non-empty scheme or netloc from `urlsplit`; require the path to start with exactly one `/` and not `//`; re-check after percent-decoding.

### ③ Interpolating fetched data into error messages

A blocked response still leaks if it prints what was fetched. Put only fixed codes and documentation links in a deny reason — never raw query results.

## 6. Preconditions

| Condition | Detail |
| --- | --- |
| Kyverno **< 1.19.2** | Fixed in 1.19.2. The CVE record narrows the range to 1.19.1–1.19.2, so treat anything below 1.19.2 as needing the upgrade |
| Tenant can **create a namespaced `Policy`** | A normal privilege in multi-tenant Kyverno, and the tenant must be able to write `apiCall` into it |
| Kyverno's admission SA has **broad RBAC** | The default install. The policy must be able to execute the path it asks for |
| Attacker can **trigger the policy and read the denial** | Any permission to create the matched resource is enough |

### Not affected / lower risk

- **1.19.2 or later** — fixed.
- **Clusters that never use `apiCall`** — this path does not exist. Still upgrade (the release carries 24 advisories).
- **Policies authored only by the platform team** — no tenant isolation bypass, but a policy author can still read with Kyverno's identity, so keep that trust boundary.
- **Environments where every user is a cluster admin** — there is no boundary to cross.

## 7. Three immediate steps

1. **Upgrade to Kyverno v1.19.2 or later.** Use your install method (Helm, kustomize, …) and confirm the deployed image tags actually changed. 1.19.2 addresses 24 advisories (9 Critical, 14 High, 1 Moderate).
2. **Minimise RBAC for creating namespaced `Policy`.** Check whether tenants in multi-tenant clusters can create `policies.kyverno.io` and revoke or restrict it. Absorb tenant needs with **platform-authored policies plus parameters**.
3. **Apply three rules to your own URL validation.** ① parse first with a URL parser (`net/url`, `urlsplit`) ② compare by path segment position, not by regex ③ execute only the string that was validated. Never validate a URL with a file path function (`path.Clean`, `normpath`).

```bash
# quick grep (the script below is the thorough version)
grep -rnE 'path\.Clean|posixpath\.normpath|startswith\("/"\)' --include='*.go' --include='*.py' .
```

## 8. Exposure check

`check_kyverno_parser.sh` is **read-only**: `get`/`list` against the cluster and `grep` against source.

```bash
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/kyverno-url-parser-ghsa-pcx2-xcq4-65vf/check_kyverno_parser.sh
bash check_kyverno_parser.sh                 # cluster + current directory source
bash check_kyverno_parser.sh --dir ./src
bash check_kyverno_parser.sh --context prod --csv > kyverno_audit.csv
bash check_kyverno_parser.sh --strict        # exit 1 when a risk is found
```

| # | Check | Method |
| --- | --- | --- |
| 1 | Kyverno version in the cluster (image tag) vs 1.19.2 | `kubectl get deployments -A -o jsonpath` |
| 2 | Namespaced `Policy` list and **`apiCall` usage** | `kubectl get policies.kyverno.io -A` + per-policy `-o yaml` grep |
| 3 | Policies whose `urlPath` carries a `?`, `#` or `%3F` decoy | policy YAML grep |
| 4 | `path.Clean`, `normpath`, `startswith("/")` patterns in source | `grep -rn` |

Sample output (values are illustrative):

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

Verdict codes: `ACT_NOW` (below 1.19.2) · `OK` · `VERIFY` (unreadable tag: `latest`, digest) · `DECOY` (namespace string inside a query or fragment) · `USES_APICALL` (uses apiCall, no decoy) · `SKIP` (no CRD, no permission, no connection).
Options: `--context` · `--kubeconfig` · `--dir` · `--csv` · `--strict` · `--skip-cluster` · `--skip-source` · `--kubectl PATH` (stub binary for tests).

[`url_validator_example.py`](url_validator_example.py) puts a vulnerable validator next to a safe `urlsplit`-based one and runs six cases.

```bash
python3 url_validator_example.py
```

## 9. Detection hints

- A Kyverno ServiceAccount request whose **URI carries `/namespaces/` inside the query string** is unusual for a legitimate policy. Look at the API server audit log for requests from the Kyverno admission SA (`system:serviceaccount:kyverno:kyverno-admission-controller` and friends). (This is inference from the fix commit's note that execution sends path+query.)
- Record **creation of a `Policy` containing `apiCall`** in a tenant namespace. It is a rare event in normal operations.
- Watch for admission denial bodies that contain what looks like ConfigMap or Secret values.

## 10. Two-minute summary

- On **Kyverno < 1.19.2**, a namespaced `Policy` with `apiCall.urlPath` set to `?x=/namespaces/<own-ns>/` **bypasses namespace isolation**.
- The cause is a **parser differential between `path.Clean` (file path) and `net/url` (URL)**, plus a TOCTOU-shaped split between the validated and executed value.
- Exfiltration happens through the **deny message**: a blocked response is the leak channel.
- **Do**: ① upgrade to 1.19.2 ② minimise tenant `Policy`-creation RBAC ③ replace in-house URL validation with "parse → compare path segments → execute the validated value".
- Ordinary web apps share the flaw. **Parse the URL with a URL parser first**; never validate it with a file path function.

## Sources

- GitHub Advisory — GHSA-pcx2-xcq4-65vf (kyverno/kyverno, Critical): https://github.com/kyverno/kyverno/security/advisories/GHSA-pcx2-xcq4-65vf
- Akamai Security Research — How a URL Parser Differential Broke Kyverno's Namespace Isolation (2026-11-24, CVSS 10.0, 4% telemetry): https://www.akamai.com/blog/security-research/url-parser-differential-broke-kyvernos-namespace-isolation
- Fix commit — `f67231d` `[1.19] fix(security): API path validation, apiCall canonicalization...` (#17984): https://github.com/kyverno/kyverno/commit/f67231def576eb0ad153dd8cbfc836908ab14c14
- Release — Kyverno v1.19.2 (24 advisories): https://github.com/kyverno/kyverno/releases/tag/v1.19.2
- CVE record — CVE-2026-122312 (CVSS v4 8.3, 1.19.1–1.19.2): https://www.cve.org/cverecord?id=CVE-2026-122312 · https://osv.dev/vulnerability/BIT-kyverno-2026-122312
- Prior vulnerability — CVE-2026-22039 / GHSA-8p9x-46gm-qfx2 (where namespace confinement began): https://github.com/advisories/GHSA-8p9x-46gm-qfx2

Last verified: 2026-11-27. Affected ranges and scores can change; check Kyverno's notices together with the advisory.
