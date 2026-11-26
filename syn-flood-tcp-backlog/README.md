# SYN Flood — 대역폭이 아니라 대기열을 채우는 공격 (기술 시각화 02)

[한국어](README.md) | [English](README_en.md)

SYN Flood는 트래픽 양으로 회선을 채우는 공격이 아닙니다. **연결을 맺는 중간 상태(half-open)를 큐에 쌓아** 정상 사용자의 자리를 없애는 공격입니다. 128칸짜리 대기열이 차면, 진짜 손님은 SYN을 보내도 큐에 들어가지 못합니다.

이 문서는 릴스 「기술 시각화 02」의 원문 정리입니다. 3-Way Handshake에서 어느 순간에 자원이 잡히는지, 두 개의 큐(SYN queue · accept queue)를 어떻게 구분하는지, SYN cookie가 무엇을 잃는지, 그리고 [`check_syn_backlog.sh`](check_syn_backlog.sh)로 읽기 전용 점검하는 방법을 담았습니다.

## 한눈에

| 항목 | 내용 |
| --- | --- |
| 공격 계층 | TCP (L4) — 3-Way Handshake의 마지막 ACK을 보내지 않음 |
| 고갈 대상 | **SYN queue**(half-open) → 그다음 **accept queue** |
| 커널 손잡이 | `net.ipv4.tcp_max_syn_backlog` · `net.core.somaxconn` · listen backlog · `tcp_syncookies` · `tcp_synack_retries` |
| 대표 오해 | "SYN Flood = 대역폭 공격" → 실제로는 **작은 패킷으로 큐를 점유**하는 자원 고갈 |
| 핵심 방어 | SYN cookie(무상태 검증) · 백로그 상향 · 앞단 프록시/CDN · XDP |
| 진단 | `ss -lnt`(Recv-Q/Send-Q) · `nstat TcpExt*` · [`check_syn_backlog.sh`](check_syn_backlog.sh) |
| 릴스 길이 | 28초 (2026-11-27 제작) |

## 1. 무슨 문제인가 — 카페 진동벨 비유

릴스는 이렇게 설명합니다.

- 손님은 **주문(SYN)**만 하고 **진동벨**을 받아 간다. **확인(ACK)**은 오지 않는다.
- 알바생은 벨을 미리 만들어 두고, 자리(연결 상태)를 예약해 둔다.
- 128칸이 차면 **진짜 손님은 SYN을 보내도 큐에 못 들어간다**.

방어의 방향은 "벨을 더 많이 만드는 것"이 아니라 **"벨을 미리 만들지 않는 것"**입니다. SYN cookie는 상태를 저장하지 않고, 돌아온 ACK의 값을 계산으로 검증합니다.

## 2. 3-Way Handshake — 어디서 자원이 잡히는가

| 단계 | 패킷 | 서버 상태 | 자원 |
| --- | --- | --- | --- |
| ① | 클라이언트 → **SYN** | `LISTEN` → `SYN_RECV` | **SYN queue**에 half-open 항목 생성 |
| ② | 서버 → **SYN-ACK** | SYN-ACK 재전송 대기 | `tcp_synack_retries`만큼 대기(기본 5 ≈ 31초) |
| ③ | 클라이언트 → **ACK** | `ESTABLISHED` → **accept queue**로 이동 | 애플리케이션이 `accept()`해야 사라짐 |

핵심은 **③번이 와야만 자원이 확정된다**는 점입니다. ③이 오지 않으면 서버는 ②를 반복하며 항목을 붙잡고 있습니다. 공격자는 이 구간을 노립니다.

### 두 개의 큐를 구분해야 한다

| 큐 | 무엇이 쌓이나 | 상한을 정하는 값 | 확인 방법 |
| --- | --- | --- | --- |
| **SYN queue** (incomplete) | SYN을 받고 ACK을 기다리는 half-open | `net.ipv4.tcp_max_syn_backlog` | 직접 조회 어려움 — `TcpExt*` 카운터로 간접 확인 |
| **accept queue** (complete) | 핸드셰이크가 끝났지만 앱이 `accept()`하지 않은 연결 | `min(listen(backlog), net.core.somaxconn)` | `ss -lnt`의 **Recv-Q** |

`ss -lnt` 출력에서 **LISTEN 소켓의 `Recv-Q`는 현재 accept 큐에 대기 중인 연결 수**, **`Send-Q`는 그 소켓의 accept 큐 상한**(`min(backlog, somaxconn)`)입니다. `Recv-Q`가 지속적으로 0이 아니면 SYN Flood가 아니라 **애플리케이션이 accept를 못 따라가는 상태**일 수 있습니다. 원인이 다르므로 먼저 구분해야 합니다.

## 3. SYN Flood가 성립하는 조건

| 조건 | 설명 |
| --- | --- |
| 스푸핑 가능한 출발지 | 오지 않을 주소로 SYN을 보내면 SYN-ACK가 엉뚱한 곳으로 가고 ACK은 영원히 없다 |
| 작은 패킷으로 충분 | 40~60바이트 요청 하나가 서버 쪽에서는 큐 항목 하나를 차지한다 |
| 큐 상한이 작음 | `tcp_max_syn_backlog` 128~1024 구간이 흔하다 |
| 서버가 SYN-ACK를 재전송 | `tcp_synack_retries=5`면 한 항목이 약 31초간 자리를 잡는다 |

> 대역폭을 채우는 Flood(예: UDP amplification)와 구분해야 대응이 갈립니다. SYN Flood는 **회선이 남아 있어도 서비스가 멈춥니다.**

## 4. SYN cookie — 상태를 저장하지 않는 검증

`net.ipv4.tcp_syncookies=1`이면 SYN queue가 넘치는 순간부터 서버는 **항목을 저장하지 않고** 아래 값을 계산해 `SYN-ACK`의 시퀀스 번호에 싣습니다.

```
cookie = MAC(비밀키, 출발지 IP·포트, 목적지 IP·포트, 시간, MSS index)
```

클라이언트가 ACK을 보내면 서버는 저장된 상태 대신 **쿠키를 다시 계산해 비교**합니다. 맞으면 그때 연결 상태를 만들고 accept queue로 넘깁니다. 저장 공간이 필요 없으니 큐 고갈 자체가 사라집니다.

### 대가가 있다

| 잃는 것 | 결과 |
| --- | --- |
| 옵션 공간 | MSS는 3비트 인덱스(8단계)로만 표현 → 최적 MSS를 못 쓸 수 있음 |
| 윈도 스케일·SACK·타임스탬프 협상 | 쿠키 경로에서는 옵션 협상이 제한됨 → 처리량이 일시적으로 떨어질 수 있음 |
| 방화벽·LB의 세션 추적 | 시퀀스 번호가 예측 불가해져 일부 장비가 연결을 막을 수 있음 |

그래서 커널 기본값은 **`1`(필요할 때만)** 이고, RFC 4987도 SYN cookie를 **최후 수단**으로 둡니다. 상시 `2`(항상)로 두면 테스트 외에는 이득이 없습니다.

## 5. 진단 — 무엇을 보는가

### 5-1. accept queue 상태

```bash
ss -lnt | head             # LISTEN 소켓의 Recv-Q(대기) / Send-Q(상한)
ss -lnt 'sport = :443'     # 특정 포트만
```

### 5-2. 커널 카운터

```bash
nstat -az TcpExtTCPReqQFullDrop TcpExtTCPReqQFullDoCookies \
          TcpExtListenOverflows TcpExtListenDrops \
          TcpExtSyncookiesSent TcpExtSyncookiesRecv TcpExtSyncookiesFailed
```

| 카운터 | 의미 |
| --- | --- |
| `TcpExtTCPReqQFullDrop` | SYN queue 포화로 SYN을 버린 횟수 — **공격/포화의 직접 신호** |
| `TcpExtTCPReqQFullDoCookies` | 포화 시 쿠키로 응답한 횟수 (방어가 동작한 횟수) |
| `TcpExtListenOverflows` | accept queue 오버플로 — 핸드셰이크는 됐지만 앱이 못 받음 |
| `TcpExtListenDrops` | accept 단계 드롭(위 항목 포함) |
| `TcpExtSyncookiesSent` / `Recv` / `Failed` | 쿠키 사용·검증 통계 |
| `TcpExtEmbryonicRsts` | half-open 단계에서 RST를 받은 수 |

> **`TcpExtSYNdrop`은 메인라인 커널의 카운터 이름이 아닙니다.** `nstat -az TcpExtSYNdrop`은 아무 행도 출력하지 않습니다(존재하지 않는 키는 조용히 무시됩니다). SYN 큐 포화 신호는 위의 `TCPReqQFullDrop`·`TCPReqQFullDoCookies`·`ListenOverflows`로 읽어야 합니다. [`check_syn_backlog.sh`](check_syn_backlog.sh)는 요청대로 `TcpExtSYNdrop`도 조회하되, 값이 없으면 `N/A(이 커널에 없는 카운터)`로 표시합니다.

### 5-3. 스크립트

```bash
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/syn-flood-tcp-backlog/check_syn_backlog.sh
bash check_syn_backlog.sh                  # 사람이 읽는 표
bash check_syn_backlog.sh --csv > syn.csv  # 스프레드시트·티켓 첨부용
bash check_syn_backlog.sh --strict         # 위험 항목이 있으면 종료코드 1
bash check_syn_backlog.sh --port 443       # 특정 포트만
```

읽는 항목: 커널·배포판, 관련 sysctl 6개, LISTEN 소켓별 `Recv-Q`/`Send-Q`, SYN·accept 큐 카운터 9개. **`sysctl -w`도 netlink 쓰기도 없는 읽기 전용**이며, `ss`·`nstat`·`/proc`만 사용합니다.

출력 예시(이 저장소를 만든 컨테이너에서 실제 실행, 값은 환경마다 다름):

```
== 2. 관련 sysctl (읽기 전용) ==
net.ipv4.tcp_syncookies            1          OK (필요 시 사용)
net.ipv4.tcp_max_syn_backlog       128        LOW (512 미만) → SYN queue 상한
net.core.somaxconn                 4096       OK → accept queue 상한(listen 백로그와 min)
net.ipv4.tcp_synack_retries        5          SYN-ACK 재전송 횟수(기본 5 ≈ 31초 대기)
net.ipv4.tcp_abort_on_overflow     0          1이면 오버플로 시 RST(기본 0=조용히 버림)
net.core.netdev_max_backlog        1000       NIC 수신 큐(별도 계층)

== 3. LISTEN 소켓 (ss -lntH) ==
STATE  RECV-Q(대기)     SEND-Q(상한) LOCAL
LISTEN 0                  0            127.0.0.1:35797
LISTEN 0                  0            127.0.0.1:44111

LISTEN 소켓 수                  2
accept queue 대기 합계         0

== 4. SYN·accept 큐 커널 카운터 (nstat, 부팅 이후 누적) ==
COUNTER                        VALUE        NOTE
TcpExtSYNdrop                      N/A        이 커널에 없는 카운터(메인라인 미제공)
TcpExtTCPReqQFullDrop              0
TcpExtTCPReqQFullDoCookies         0
TcpExtListenOverflows              0
TcpExtListenDrops                  0
TcpExtSyncookiesSent               0
TcpExtSyncookiesRecv               0
TcpExtSyncookiesFailed             0
TcpExtEmbryonicRsts                0
```

## 6. 튜닝 — 값을 올리기 전에

| sysctl | 흔한 기본값 | 권장 판단 |
| --- | --- | --- |
| `net.ipv4.tcp_syncookies` | `1` | **끄지 않는다.** 0이면 큐 포화가 곧 드롭이다 |
| `net.ipv4.tcp_max_syn_backlog` | 128~4096 | 트래픽 규모에 맞춰 상향. 다만 상향은 **버티는 시간을 늘릴 뿐** 근본 대응은 아니다 |
| `net.core.somaxconn` | 4096 (5.4+) | 앱의 listen backlog와 함께 올린다. 한쪽만 올리면 `min()`에서 잘린다 |
| listen backlog (앱 설정) | nginx `511` 등 | `somaxconn` 이하로 두고, 처리량에 맞춰 조정 |
| `net.ipv4.tcp_synack_retries` | `5` (~31초) | 낮추면 half-open 점유 시간이 줄지만, 느린 정상 클라이언트도 실패할 수 있다 |
| `net.ipv4.tcp_abort_on_overflow` | `0` | 1이면 큐 오버플로 시 RST — 클라이언트에 즉시 알리지만 재시도 폭주 위험 |

> 백로그 상향은 **메모리와 지연을 함께 늘립니다**. 큐가 길어지면 정상 요청의 대기 시간이 늘고, 공격이 끝난 뒤에도 오래 남습니다. 수치는 부하 테스트로 정하고, 상향 후에는 `TCPReqQFullDrop`이 실제로 줄었는지 확인하세요.

## 7. 대응 순서

1. **현재 상태 측정** — `check_syn_backlog.sh`로 syncookies·백로그·accept queue를 먼저 본다.
2. **원인 구분** — `TCPReqQFullDrop`이 늘면 SYN 큐 포화, `ListenOverflows`만 늘면 앱 accept 지연.
3. **즉시 완화** — 앞단 LB/CDN에서 SYN 프록시·rate limit 적용, 필요하면 `netfilter`의 `SYNPROXY` 타깃(무상태 검증 후 백엔드에 연결 전달) 도입.
4. **구조 개선** — XDP/DPDK 기반 L4 방어, 애니캐스트 분산, 오토스케일. SYN cookie는 마지막 겹으로 남긴다.
5. **관측 고정** — `TCPReqQFullDrop`·`ListenOverflows`·`SyncookiesSent`를 대시보드에 올리고 경보 임계값을 정한다.

```bash
# 참고: nftables SYNPROXY 예시 (적용 전 staging 검증 필수, 이 저장소는 스크립트로 제공하지 않음)
# nft add rule inet filter input tcp dport 443 ct state invalid counter drop
# nft add rule inet filter input tcp dport 443 tcp flags & (fin|syn|rst|ack) == syn \
#   ct state untracked counter synproxy mss 1460 wscale 7 timestamp sack-perm
```

> 위 규칙은 방화벽 상태를 바꿉니다. 이 저장소의 점검 스크립트는 이런 변경을 하지 않습니다. 적용은 변경 관리 절차를 따르세요.

## 8. 2분 요약

- SYN Flood는 **대역폭이 아니라 대기열** 공격이다. ACK을 안 보내면 서버가 31초간 자리를 잡아둔다.
- 큐는 두 개다. **SYN queue**(`tcp_max_syn_backlog`)와 **accept queue**(`min(listen backlog, somaxconn)`). `ss -lnt`의 `Recv-Q`는 후자다.
- SYN cookie는 **상태를 저장하지 않고 계산으로 검증**한다. 대신 MSS·옵션 협상을 일부 잃는다.
- 진단은 `TCPReqQFullDrop`·`ListenOverflows`·`SyncookiesSent`. **`TcpExtSYNdrop`이라는 카운터는 없다.**
- 백로그 상향은 시간을 벌 뿐이다. 앞단 SYN 프록시·XDP·애니캐스트와 함께 설계해야 한다.

## 출처

- RFC 9293 — Transmission Control Protocol (TCP): https://www.rfc-editor.org/rfc/rfc9293.html
- RFC 4987 — TCP SYN Flooding Attacks and Common Mitigations: https://www.rfc-editor.org/rfc/rfc4987.html
- Linux kernel — ip-sysctl 문서(`tcp_syncookies`, `tcp_max_syn_backlog`, `tcp_synack_retries`, `somaxconn`): https://docs.kernel.org/networking/ip-sysctl.html
- iproute2 — `ss(8)`, `nstat(8)`: https://man7.org/linux/man-pages/man8/ss.8.html · https://man7.org/linux/man-pages/man8/nstat.8.html
- netfilter — SYNPROXY: https://docs.kernel.org/networking/netfilter-synproxy.html

확인 기준일: 2026-11-27. 기본값은 커널 버전·배포판·컨테이너 런타임에 따라 다릅니다. 이 문서의 수치는 예시 환경의 실측값이며, 적용 전에 대상 호스트에서 직접 확인하세요.
