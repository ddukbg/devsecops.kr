# Java4Shell · NGINX2Shell — 발동 조건부터 확인하는 실무 점검

[한국어](README.md) | [English](README_en.md)

2026-11-17 공개된 OpenJDK 취약점(Java4Shell)과 NGINX HTTP/2 취약점(NGINX2Shell)은 둘 다 RCE로 분류되지만, **모든 서버가 해당되는 것은 아닙니다.** CPU 명령어 집합과 프록시 설정이라는 발동 조건을 먼저 확인하는 것이 패치 우선순위를 정하는 길입니다.

## 한눈에

| 항목 | Java4Shell | NGINX2Shell |
| --- | --- | --- |
| CVE | CVE-2026-114938 (외 6건) | CVE-2026-123007, CVE-2026-123633 |
| 대상 | OpenJDK 17–27 (x86-64) | NGINX 1.21.4–1.31.9, 1.30.x |
| 발동 조건 | **AVX-512 VBMI CPU** + 외부 Base64 페이로드 | **HTTP/2 활성** + 리버스 프록시 커넥션 재사용 |
| 비해당 | Java 8·11, ARM64 | HTTP/2 비활성 |
| 고정 버전 | 17.0.21.1 / 21.0.13.1 등 | 1.31.10 / 1.30.8 |

## 1. Java4Shell (CVE-2026-114938)

- OpenJDK **17–27**의 HotSpot Base64 인트린직에서 발생합니다. x86-64 **AVX-512 VBMI** 명령을 쓰는 CPU에서 외부 Base64 페이로드로 RCE가 가능합니다.
- **Java 8·11과 ARM64는 해당 없음.** 공개 시점 기준 공개 익스플로잇은 없었습니다.
- OpenJDK 권고(2026-11-17)가 고정한 버전: `27.0.1.0.3`, `25.0.5.0.3`, `21.0.13.0.3`, `17.0.21.0.3`, `11.0.33`, `8u512`.

### 위험도 매트릭스 (같이 패치된 CVE)

| CVE | 컴포넌트 | CVSS |
| --- | --- | --- |
| CVE-2026-114938 | hotspot/compiler | 8.1 |
| CVE-2026-114939 | security-libs/org.ietf.jgss | 7.4 |
| CVE-2026-114940 | security-libs/javax.net.ssl | 7.4 |
| CVE-2026-114941 | hotspot/compiler | 7.0 |
| CVE-2026-114942 | core-libs | 7.0 |
| CVE-2026-114943 | hotspot/runtime | 6.5 |
| CVE-2026-114944 | core-svc/java.lang.management | 5.9 |

### 내 서버가 해당하는지

```bash
java -version
# AVX-512 VBMI 지원 여부 (출력이 있으면 Java4Shell 발동 조건 충족 가능)
lscpu | grep -o avx512_vbmi
# JVM이 AVX-512를 실제로 쓰는지 (UseAVX = 3 이면 AVX-512 사용)
java -XX:+PrintFlagsFinal -version 2>/dev/null | grep UseAVX
```

- `UseAVX = 3` + x86-64 + Java 17–27이면 **즉시 패치 대상**입니다.
- 패치 전 임시 완화: `export JAVA_TOOL_OPTIONS='-XX:-UseBase64Intrinsics'`
  (성능 영향이 있고 근본 해결이 아니므로 패치 전까지만 사용)

## 2. NGINX2Shell (CVE-2026-123007 / CVE-2026-123633)

- NGINX **1.21.4–1.31.9**, 1.30.x에서 **HTTP/2가 켜져 있고** 리버스 프록시 커넥션을 재사용하는 구성이면 원격 코드 실행으로 이어질 수 있습니다.
- `CVE-2026-123633`은 HTTP/2 비활성 시 해당 없음.

```bash
nginx -v
# http2 지시어가 실제 적용 중인지 확인
sudo nginx -T 2>/dev/null | grep -n http2
```

- HTTP/2를 쓰지 않는 서버는 `http2 off;` 로 끄고 리로드하는 것만으로 노출을 줄일 수 있습니다.
- 고정 버전: **1.31.10 / 1.30.8** (NGINX2Root 후속 패치).

## 3. 패치와 검증

1. OpenJDK는 배포판 패키지가 아니라 **실행 중인 JVM 바이너리**를 확인합니다. 컨테이너 이미지 태그만 보고 끝내지 마세요.
2. NGINX는 `reload` 후에도 **구 워커 바이너리가 남을 수 있습니다.** `restart` 또는 `USR2` 바이너리 교체로 확인합니다.
3. Docker 공식 하드닝 이미지는 2026-11-19 패치본이 배포됐습니다. 베이스 이미지 digest를 갱신합니다.

## 4. 점검 스크립트

[`check_java_nginx_exposure.sh`](check_java_nginx_exposure.sh) — 읽기 전용. 실행 중인 Java·NGINX의 발동 조건만 확인합니다.

```bash
bash check_java_nginx_exposure.sh
```

## 출처

- OpenJDK Vulnerability Advisory (2026-11-17): https://openjdk.org/groups/vulnerability/advisories/2026-11-17
- Docker blog — patches for Java4Shell and NGINX HTTP/2: https://www.docker.com/blog/docker-patches-java4shell-and-the-nginx-http-2-with-docker-hardened-images/

확인 기준일: 2026-11-26. 공개 익스플로잇 상황은 달라질 수 있으므로 벤더 권고를 재확인하세요.
