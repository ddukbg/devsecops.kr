# SSRF — the URL parser differential that opens the internal network (Tech Visual 01)

[한국어](README.md) | [English](README_en.md)

`https://169.254.169.254/?from=api.trusted.com` — a string check sees `trusted.com` and passes it; the HTTP client reads the host as `169.254.169.254`. SSRF (Server-Side Request Forgery) is not a flaw in one endpoint but **two pieces of code reading the same string differently**: the validator and the connector.

This is the write-up behind the Reel "Tech Visual 01": where parsers diverge, six variants that change only the notation, and four layers of defence including IMDSv2 `hop limit 1`. Test payloads are in [`ssrf_payloads.txt`](ssrf_payloads.txt); a validator that parses once is in [`safe_url_check.py`](safe_url_check.py).

## At a glance

| Item | Detail |
| --- | --- |
| Class | CWE-918 Server-Side Request Forgery |
| Root cause | **URL parser differential** between the validator and the HTTP client (file-path helpers or substring checks vs an RFC 3986 parser) |
| Typical targets | `169.254.169.254` (cloud IMDS), `10.96.0.1` (Kubernetes API Service), `127.0.0.1`, internal Redis and admin ports |
| One request | Public API call → IMDS query → temporary credentials retrieved (0.42s in the Reel is a sequence, not a measurement) |
| Variants | `@` userinfo · decimal/hex IP · IPv6 mapping · 302 redirect · fragment (`#@`) |
| Material | [`ssrf_payloads.txt`](ssrf_payloads.txt) · [`safe_url_check.py`](safe_url_check.py) |
| Defence | ① parse once and request with that result ② exact host match + post-DNS IP check ③ block redirects · IMDSv2 ④ egress allowlist |

> The scenario is reconstructed from public standards (RFC 3986) and cloud vendor documentation. It does not cite a specific service's breach.

## 1. What the flaw is

SSRF needs two things at once.

1. **The user can influence part of the destination** — URL, callback address, image/PDF fetch, webhook, proxy, link preview, translation.
2. **The request leaves from inside the server's trust boundary** — the server can reach internal services and the metadata endpoint; the user cannot.

So defence usually starts with an allowlist. The problem appears when the allowlist is checked **as a string**.

```python
if "trusted.com" in url:      # validator: passes if the text appears anywhere
    requests.get(url)          # client: parses the URL and connects to its host
```

`https://169.254.169.254/?from=api.trusted.com` satisfies both lines. The validator reads as far as the query and finds `trusted.com`; the client reads only the authority and connects to `169.254.169.254`. **Same string, different destination.**

## 2. Root cause — where the two readings split

### 2-1. `?` means different things on each side

RFC 3986 splits a URL into `scheme://authority/path?query#fragment`.

| Part | What the validator sees | What the client uses |
| --- | --- | --- |
| `https://169.254.169.254/` | part of a string | **host** — the actual connection target |
| `?from=api.trusted.com` | contains `trusted.com` → allow | **query** — sent to the server |
| `#@169.254.169.254` | part of a string | **fragment** — never sent |

Checking the whole string while connecting to the authority is half of every SSRF.

### 2-2. Mixing parsers makes it worse

| Validator helper | `?` handling | Result |
| --- | --- | --- |
| Substring check (`in`, `startswith`) | no meaning | anything in the query passes |
| File-path normalisation (`path.Clean`, `posixpath.normpath`) | ordinary character | passes regex and prefix checks |
| URL parser (`net/url`, `urllib.parse.urlsplit`) | starts the query | host isolated correctly |

The Kyverno `apiCall` case (`GHSA-pcx2-xcq4-65vf`) has the same root: validation with `path.Clean`, execution with `net/url`. See [`kyverno-url-parser-ghsa-pcx2-xcq4-65vf`](../kyverno-url-parser-ghsa-pcx2-xcq4-65vf/README_en.md) for that Kubernetes version of the same bug.

### 2-3. Re-parsing after validation (TOCTOU)

If the value changes between validation and request, the same gap reopens.

- **DNS rebinding**: resolves to a public IP at check time, `127.0.0.1` at request time.
- **Redirects**: an allowed host answers `302` pointing at an internal address.
- **Normalisation**: percent encoding, case, trailing dot (`169.254.169.254.`), Unicode.

Hence the first rule: **request with the value you validated.** Do not pass the raw string back into the client — pass the parsed host, port, path and query.

## 3. Attack flow — the attacker does not forge an internal request

```
user-supplied URL
   └─ validator (allowlist passes)
        └─ HTTP client → 169.254.169.254 (IMDS)
             └─ temporary credentials → cloud API
```

1. **0.00s** public API call (looks like a normal user)
2. **0.21s** server queries IMDS (`/latest/meta-data/iam/security-credentials/`)
3. **0.42s** credentials leave in the response body or an error message

The seconds are Reel pacing, showing **order**, not measured latency. Many servers do not echo the body; those cases become blind SSRF, used to scan internal ports and services.

Reachable targets:

| Target | Address | Note |
| --- | --- | --- |
| AWS IMDS | `169.254.169.254` (IPv6 `fd00:ec2::254`) | IMDSv1 answers a plain GET |
| ECS task credentials · IRSA | `169.254.170.2` | container-only endpoint |
| EKS Pod Identity | `169.254.170.23` | per-pod credentials |
| GCP metadata | `metadata.google.internal` / `169.254.169.254` | requires `Metadata-Flavor: Google` |
| Azure IMDS | `169.254.169.254` | requires `Metadata: true` |
| Kubernetes API | `10.96.0.1` (Service), `kubernetes.default.svc` | escalates with a pod SA token |
| Local services | `127.0.0.1:6379` (Redis), `:2375` (Docker over TCP), `:8080` (admin) | unauthenticated internal ports |

> GCP and Azure require a header, so a bare GET gets nothing. Do not count that header as a defence line — a proxy-style SSRF that can set headers changes the picture.

## 4. Six variants

Same destination, different notation. A string-based allowlist lets at least one through.

| # | Payload | What it does | Validator it defeats |
| --- | --- | --- | --- |
| ① | `https://api.trusted.com@169.254.169.254/` | userinfo before `@`, host after it | checks the domain before `@` |
| ② | `http://2852039166/` | decimal form of `169.254.169.254` | regex expecting four dot-separated octets |
| ③ | `http://0xA9FEA9FE/` | hex form of the same address | rules that only cover decimal |
| ④ | `http://[::ffff:a9fe:a9fe]/` | IPv4-mapped IPv6 notation | rules that only block IPv4 ranges |
| ⑤ | `https://api.trusted.com/redirect?to=169.254.169.254` | allowed host answers `302` to an internal address | validates the first hop, follows redirects |
| ⑥ | `https://169.254.169.254/#@api.trusted.com` | fragment is never sent to the server | inspects the string past `#` |

Related families (same principle):

- **Trailing dot and case**: `169.254.169.254.`, `LOCALHOST`, `127.1`, `0x7f.1`
- **Percent encoding**: `169.254.169.254%2f`, `%31%36%39.254.169.254`
- **DNS rebinding**: public IP on the first lookup, private IP on the second
- **Octal and mixed notation**: `0251.0376.0251.0376`
- **Wildcard DNS**: services such as `169.254.169.254.nip.io`

Library behaviour differs for IPv6 literals and userinfo. Judge by **what your stack's client actually connects to**, not by what the RFC allows. `ssrf_payloads.txt` notes which check each entry defeats.

## 5. Four layers of defence

### ① Parse once, then request

```python
from urllib.parse import urlsplit

parts = urlsplit(raw)                 # parse exactly once
host = (parts.hostname or "").lower() # use only these values below
# build both the check and the request from host / port / path
```

`requests.get(raw)` re-parses the string and the two readings diverge again.

### ② Exact host match + post-DNS IP check

- Compare with **exact equality** (`api.trusted.com`) or an explicit subdomain rule (ends with `.trusted.com` at a label boundary). Never `in` or `startswith("api.")`.
- Even when the name matches, **check the resolved IPs** with `ipaddress` and reject all of:

```text
0.0.0.0/8  10.0.0.0/8  100.64.0.0/10  127.0.0.0/8  169.254.0.0/16
172.16.0.0/12  192.168.0.0/16  198.18.0.0/15  224.0.0.0/4  240.0.0.0/4
::1/128  fc00::/7  fe80::/10  ::ffff:0:0/96
```

- If the name resolves to several addresses, check **all** of them; one blocked range means fail.

### ③ No redirects · IMDSv2 `hop limit 1`

- Disable redirects in the client, or re-validate every hop (`allow_redirects=False`, `max_redirects=0`).
- Add a cloud-side layer. AWS IMDSv2 requires a PUT token, and `http-put-response-hop-limit` set to **1** stops requests that cross a container or proxy hop.

```bash
# inspect first (read-only); changing it needs an approved change
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{id:InstanceId,imds:MetadataOptions}' --output table

# example change: tokens required + hop limit 1
aws ec2 modify-instance-metadata-options \
  --instance-id i-0123456789abcdef0 \
  --http-tokens required --http-put-response-hop-limit 1
```

> `hop limit 1` **cuts pods that call IMDS directly**. Workloads that use IRSA or EKS Pod Identity (`169.254.170.2`, `169.254.170.23`) are unaffected, so move credential-hungry pods there. If an application still calls IMDSv1 directly, migrate it to the SDK or IRSA first.

### ④ Egress allowlist — in the network, not the code

Application checks fail when a single code path forgets them. The last line is the network.

- Security groups, NACLs and NetworkPolicy should deny outbound to `169.254.0.0/16`, cluster CIDRs and metadata addresses by default.
- Through a proxy, enforce a **host allowlist and private-range denial** at the proxy.
- Apply the same standard to serverless and managed runtimes: VPC egress policy plus metadata options.

## 6. Preconditions

| Condition | Detail |
| --- | --- |
| User input becomes part of the destination | URL, callback, image/PDF fetch, webhook, preview, proxy |
| Server can reach internal services or metadata | usually the default |
| Validation is string-based or uses a different parser | `in`, `startswith`, `path.Clean`, regex prefixes |
| Response returns to the user or lands in an error | otherwise it degrades to blind SSRF |

### Not applicable / lower risk

- **Destination fixed in code** (the user only supplies parameters) — the trust boundary does not open.
- **Egress closed by allowlist** — SSRF may exist but there is nowhere to go.
- **IMDSv2 only with hop limit 1** — the credential path is closed (internal scanning remains).

## 7. Checking

### 7-1. Find it in code

```bash
grep -rnE '"(trusted|allowed)[^"]*"\s+in\s+|startswith\(["'"'"']https?://|\.hostname\s*==|path\.Clean|normpath' \
  --include='*.py' --include='*.go' --include='*.js' --include='*.ts' .
```

- [ ] Is the value used for the request the **same parse result** used for the check?
- [ ] Is the allowlist an **exact match** (not `in`, not a prefix)?
- [ ] Is there an **IP range check after DNS resolution**?
- [ ] Does the client follow redirects (check the default of `allow_redirects`)?
- [ ] Do errors or logs carry the internal response body?

### 7-2. Run the example

[`safe_url_check.py`](safe_url_check.py) has no dependencies and makes no outbound request. It runs each URL through ①a substring check ②`urlsplit` ③an IP range check and shows **which check catches what**.

```bash
python3 safe_url_check.py
```

```
# actual output (2026-11-27, Python 3)
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

self-check passed: 10 cases — a substring-only check lets 4 of them through
```

The four rows where `substr` is `PASS` but the verdict is `BLOCK` are the point. In code that relies on the substring check alone, all four pass.

### 7-3. Payload list

[`ssrf_payloads.txt`](ssrf_payloads.txt) contains the variants above. Use it **only against your own staging endpoints**; testing third-party services without permission is illegal in most jurisdictions.

## 8. Two-minute summary

- SSRF is **two readers of one string**. Text after `?` is visible to the check and irrelevant to the connection.
- Notation alone is enough — `@` userinfo, decimal/hex IP, IPv6 mapping, 302, fragment.
- Defence stacks in this order: **parse once → exact match → IP range check → block redirects → IMDSv2 hop limit 1 → egress allowlist**.
- The one line to check today: **is the host check a string comparison or a comparison of the parsed result?**

## Sources

- RFC 3986 — URI Generic Syntax (§3.2 authority): https://www.rfc-editor.org/rfc/rfc3986#section-3.2
- OWASP — Server-Side Request Forgery Prevention Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html
- AWS — Instance Metadata Service (IMDSv2, hop limit): https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html
- AWS — ECS task credentials endpoint (`169.254.170.2`): https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
- AWS — EKS Pod Identity (`169.254.170.23`): https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- Google Cloud — Metadata server: https://cloud.google.com/compute/docs/metadata/overview
- Microsoft — Azure Instance Metadata Service: https://learn.microsoft.com/en-us/azure/virtual-machines/instance-metadata-service

Checked on 2026-11-27. Metadata endpoint addresses and default hop limits vary by region, runtime and launch date; confirm against the service documentation before applying.
