# Java4Shell · NGINX2Shell — check the trigger conditions before you patch

[한국어](README.md) | [English](README_en.md)

The OpenJDK vulnerability (Java4Shell) and the NGINX HTTP/2 vulnerability (NGINX2Shell) made public on 2026-11-17 are both rated RCE, but **not every server is in scope.** Checking the CPU instruction set and proxy configuration first is how you set patch priority.

## At a glance

| Item | Java4Shell | NGINX2Shell |
| --- | --- | --- |
| CVE | CVE-2026-114938 (+6 more) | CVE-2026-123007, CVE-2026-123633 |
| Target | OpenJDK 17–27 (x86-64) | NGINX 1.21.4–1.31.9, 1.30.x |
| Trigger | **AVX-512 VBMI CPU** + external Base64 payload | **HTTP/2 enabled** + reverse proxy connection reuse |
| Not affected | Java 8/11, ARM64 | HTTP/2 disabled |
| Fixed | 17.0.21.1 / 21.0.13.1 | 1.31.10 / 1.30.8 |

## 1. Java4Shell (CVE-2026-114938)

- Occurs in the HotSpot Base64 intrinsic of OpenJDK **17–27**. On CPUs with x86-64 **AVX-512 VBMI**, an external Base64 payload can achieve RCE.
- **Java 8/11 and ARM64 are not affected.** No public exploit was available at disclosure.
- Versions listed as affected by the OpenJDK advisory (2026-11-17): `27.0.1.0.3`, `25.0.5.0.3`, `21.0.13.0.3`, `17.0.21.0.3`, `11.0.33`, `8u512`.
- Fixed versions confirmed here: **17.0.21.1 / 21.0.13.1**. For the other branches, check the fixed-version list in the OpenJDK advisory.

### Severity matrix (CVEs patched together)

| CVE | Component | CVSS |
| --- | --- | --- |
| CVE-2026-114938 | hotspot/compiler | 8.1 |
| CVE-2026-114939 | security-libs/org.ietf.jgss | 7.4 |
| CVE-2026-114940 | security-libs/javax.net.ssl | 7.4 |
| CVE-2026-114941 | hotspot/compiler | 7.0 |
| CVE-2026-114942 | core-libs | 7.0 |
| CVE-2026-114943 | hotspot/runtime | 6.5 |
| CVE-2026-114944 | core-svc/java.lang.management | 5.9 |

### Is my server affected?

```bash
java -version
# AVX-512 VBMI support (any output means the Java4Shell trigger is possible)
lscpu | grep -o avx512_vbmi
# Whether the JVM actually uses AVX-512 (UseAVX = 3 means it does)
java -XX:+PrintFlagsFinal -version 2>/dev/null | grep UseAVX
```

- `UseAVX = 3` + x86-64 + Java 17–27 means **patch now**.
- Temporary mitigation before patching: `export JAVA_TOOL_OPTIONS='-XX:-UseBase64Intrinsics'`
  (it has a performance cost and is not a fix; use it only until you patch)

## 2. NGINX2Shell (CVE-2026-123007 / CVE-2026-123633)

- On NGINX **1.21.4–1.31.9** and 1.30.x, **HTTP/2 enabled** plus reverse proxy connection reuse can lead to remote code execution.
- `CVE-2026-123633` does not apply when HTTP/2 is disabled.

```bash
nginx -v
# Check whether the http2 directive is actually in effect
sudo nginx -T 2>/dev/null | grep -n http2
```

- Servers that do not use HTTP/2 can reduce exposure just by setting `http2 off;` and reloading.
- Fixed versions: **1.31.10 / 1.30.8** (the NGINX2Root follow-up patch).

## 3. Patch and verify

1. For OpenJDK, check the **running JVM binary**, not the distribution package. Do not stop at the container image tag.
2. After an NGINX `reload`, **old worker binaries can remain.** Confirm with `restart` or a `USR2` binary upgrade.
3. Docker official hardened images shipped patched builds on 2026-11-19. Update base image digests.

## 4. Check script

[`check_java_nginx_exposure.sh`](check_java_nginx_exposure.sh) — read-only. It only reports the trigger conditions of the running Java and NGINX.

```bash
bash check_java_nginx_exposure.sh
```

## References

- OpenJDK Vulnerability Advisory (2026-11-17): https://openjdk.org/groups/vulnerability/advisories/2026-11-17
- Docker blog — patches for Java4Shell and NGINX HTTP/2: https://www.docker.com/blog/docker-patches-java4shell-and-the-nginx-http-2-with-docker-hardened-images/

Verified as of 2026-11-26. Exploit status can change; re-check the vendor advisory.
