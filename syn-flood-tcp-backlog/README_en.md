# SYN Flood — a queue attack, not a bandwidth attack (Tech Visual 02)

[한국어](README.md) | [English](README_en.md)

A SYN flood does not fill your pipe with traffic. It fills the **half-open connection queue**, so legitimate clients find no slot. When the 128-slot queue is full, a real customer sends SYN and never gets in.

This is the write-up behind the Reel "Tech Visual 02": when the 3-way handshake reserves resources, how to tell the two queues apart (SYN queue vs accept queue), what SYN cookies cost, and how to audit a host read-only with [`check_syn_backlog.sh`](check_syn_backlog.sh).

## At a glance

| Item | Detail |
| --- | --- |
| Layer | TCP (L4) — the final ACK of the 3-way handshake never arrives |
| Exhausted resource | **SYN queue** (half-open), then the **accept queue** |
| Kernel knobs | `net.ipv4.tcp_max_syn_backlog` · `net.core.somaxconn` · listen backlog · `tcp_syncookies` · `tcp_synack_retries` |
| Common myth | "SYN flood = bandwidth attack" — it is **resource exhaustion with tiny packets** |
| Core defence | SYN cookies (stateless validation) · larger backlog · front proxy/CDN · XDP |
| Diagnosis | `ss -lnt` (Recv-Q/Send-Q) · `nstat TcpExt*` · [`check_syn_backlog.sh`](check_syn_backlog.sh) |
| Reel length | 28s (produced 2026-11-27) |

## 1. The cafe-buzzer analogy

The Reel frames it like this:

- A customer **orders (SYN)** and takes a **buzzer**, but never comes back to **confirm (ACK)**.
- The server reserves a seat (connection state) and keeps the buzzer on the counter.
- When 128 slots are taken, **a real customer cannot get in even by sending SYN**.

So the fix is not "more buzzers" but **"do not hand out buzzers in advance"**. SYN cookies store nothing and verify the returning ACK by computation.

## 2. The 3-way handshake — when resources are reserved

| Step | Packet | Server state | Resource |
| --- | --- | --- | --- |
| ① | client → **SYN** | `LISTEN` → `SYN_RECV` | half-open entry in the **SYN queue** |
| ② | server → **SYN-ACK** | waiting to retransmit | waits up to `tcp_synack_retries` (default 5 ≈ 31s) |
| ③ | client → **ACK** | `ESTABLISHED` → **accept queue** | cleared only when the app calls `accept()` |

Only **step ③** commits the resource. Without it, the server keeps retransmitting and holds the entry. That gap is what the attacker occupies.

### Two different queues

| Queue | What sits there | Bound by | How to see it |
| --- | --- | --- | --- |
| **SYN queue** (incomplete) | SYN received, ACK pending | `net.ipv4.tcp_max_syn_backlog` | not directly exposed — read the `TcpExt*` counters |
| **accept queue** (complete) | handshake done, app has not called `accept()` | `min(listen backlog, net.core.somaxconn)` | **Recv-Q** in `ss -lnt` |

In `ss -lnt`, for a LISTEN socket **`Recv-Q` is the number of completed connections waiting for `accept()`**, and **`Send-Q` is that socket's accept-queue limit** (`min(backlog, somaxconn)`). A `Recv-Q` that stays above zero is usually **the application not accepting fast enough**, not a SYN flood. Diagnose the cause before tuning.

## 3. Preconditions

| Condition | Detail |
| --- | --- |
| Spoofable source | Send SYN from an address that will never answer; the ACK never arrives |
| Tiny packets suffice | A 40–60 byte request occupies one queue entry on the server |
| Small queue limit | `tcp_max_syn_backlog` between 128 and 1024 is common |
| SYN-ACK retransmission | With `tcp_synack_retries=5` one entry occupies a slot for ~31 seconds |

> Distinguish this from bandwidth floods (e.g. UDP amplification): a SYN flood **stops service while the link still has capacity**.

## 4. SYN cookies — validation without state

With `net.ipv4.tcp_syncookies=1`, once the SYN queue overflows the kernel **stores nothing** and encodes a value into the `SYN-ACK` sequence number:

```
cookie = MAC(secret, src IP·port, dst IP·port, time, MSS index)
```

When the ACK returns, the server recomputes the cookie and compares. On a match it creates the connection state and moves it to the accept queue. No storage, so the queue cannot be exhausted.

### What it costs

| Lost | Consequence |
| --- | --- |
| Option space | MSS is encoded as a 3-bit index (8 steps) — the optimal MSS may not be negotiated |
| Window scaling / SACK / timestamps | limited negotiation on the cookie path — throughput can dip temporarily |
| Middlebox state tracking | unpredictable sequence numbers can make some firewalls/LBs drop the connection |

That is why the default is **`1` (only when needed)** and why RFC 4987 keeps SYN cookies as a last resort. Leaving it at `2` (always) buys nothing outside testing.

## 5. Diagnosis

### 5-1. Accept queue

```bash
ss -lnt | head             # Recv-Q (waiting) / Send-Q (limit) of LISTEN sockets
ss -lnt 'sport = :443'
```

### 5-2. Kernel counters

```bash
nstat -az TcpExtTCPReqQFullDrop TcpExtTCPReqQFullDoCookies \
          TcpExtListenOverflows TcpExtListenDrops \
          TcpExtSyncookiesSent TcpExtSyncookiesRecv TcpExtSyncookiesFailed
```

| Counter | Meaning |
| --- | --- |
| `TcpExtTCPReqQFullDrop` | SYNs dropped because the SYN queue was full — **the direct saturation signal** |
| `TcpExtTCPReqQFullDoCookies` | times the kernel answered with a cookie under overflow (defence working) |
| `TcpExtListenOverflows` | accept-queue overflow — handshake done, app did not pick it up |
| `TcpExtListenDrops` | drops at accept time (includes the above) |
| `TcpExtSyncookiesSent` / `Recv` / `Failed` | cookie usage and validation statistics |
| `TcpExtEmbryonicRsts` | RSTs received in the half-open state |

> **`TcpExtSYNdrop` is not a mainline kernel counter.** `nstat -az TcpExtSYNdrop` prints no row at all (unknown keys are silently ignored). Read SYN-queue saturation through `TCPReqQFullDrop`, `TCPReqQFullDoCookies` and `ListenOverflows`. [`check_syn_backlog.sh`](check_syn_backlog.sh) queries `TcpExtSYNdrop` as requested but labels it `N/A (not present on this kernel)`.

### 5-3. The script

```bash
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/syn-flood-tcp-backlog/check_syn_backlog.sh
bash check_syn_backlog.sh                  # human-readable table
bash check_syn_backlog.sh --csv > syn.csv  # for a ticket or spreadsheet
bash check_syn_backlog.sh --strict         # exit code 1 when a risk is found
bash check_syn_backlog.sh --port 443       # one port only
```

It reads the kernel and distribution, six sysctls, per-socket `Recv-Q`/`Send-Q`, and nine queue counters. It is **read-only**: no `sysctl -w`, no netlink writes — only `ss`, `nstat` and `/proc`.

Example output (actually run in the container that built this repo; values differ per host):

```
== 2. Related sysctl (read-only) ==
net.ipv4.tcp_syncookies            1          OK (on demand)
net.ipv4.tcp_max_syn_backlog       128        LOW (< 512) -> SYN queue limit
net.core.somaxconn                 4096       OK -> accept queue limit (min with listen backlog)
net.ipv4.tcp_synack_retries        5          SYN-ACK retries (default 5 = ~31s)
net.ipv4.tcp_abort_on_overflow     0          1 = RST on overflow (default 0 = silent drop)
net.core.netdev_max_backlog        1000       NIC receive queue (separate layer)

== 3. LISTEN sockets (ss -lntH) ==
STATE  RECV-Q(waiting)  SEND-Q(limit) LOCAL
LISTEN 0                  0            127.0.0.1:35797
LISTEN 0                  0            127.0.0.1:44111

LISTEN sockets                  2
accept queue pending total      0

== 4. SYN / accept queue counters (nstat, since boot) ==
COUNTER                        VALUE        NOTE
TcpExtSYNdrop                      N/A        not present on this kernel (not mainline)
TcpExtTCPReqQFullDrop              0
TcpExtTCPReqQFullDoCookies         0
TcpExtListenOverflows              0
TcpExtListenDrops                  0
TcpExtSyncookiesSent               0
TcpExtSyncookiesRecv               0
TcpExtSyncookiesFailed             0
TcpExtEmbryonicRsts                0
```

## 6. Tuning — before you raise anything

| sysctl | Common default | Recommendation |
| --- | --- | --- |
| `net.ipv4.tcp_syncookies` | `1` | **Do not disable.** At 0, queue overflow becomes a drop |
| `net.ipv4.tcp_max_syn_backlog` | 128–4096 | Raise to match traffic, but it only **buys time** |
| `net.core.somaxconn` | 4096 (5.4+) | Raise together with the app's listen backlog; one alone is clipped by `min()` |
| listen backlog (app) | nginx `511` etc. | Keep at or below `somaxconn`, size for throughput |
| `net.ipv4.tcp_synack_retries` | `5` (~31s) | Lowering shortens half-open occupancy but can fail slow legitimate clients |
| `net.ipv4.tcp_abort_on_overflow` | `0` | 1 sends RST on overflow — immediate feedback, but retry storms are possible |

> A larger backlog also costs memory and latency: longer queues mean slower legitimate requests and entries that outlive the attack. Size it with load tests, and confirm afterwards that `TCPReqQFullDrop` actually fell.

## 7. Response order

1. **Measure** — run `check_syn_backlog.sh` for cookies, backlog and accept queue.
2. **Separate the cause** — rising `TCPReqQFullDrop` means SYN-queue saturation; rising `ListenOverflows` alone means slow accepts.
3. **Mitigate now** — SYN proxy and rate limiting at the front LB/CDN; `netfilter` `SYNPROXY` where appropriate (stateless validation before passing to the backend).
4. **Fix the shape** — XDP/DPDK L4 filtering, anycast distribution, autoscaling. Keep SYN cookies as the last layer.
5. **Make it observable** — dashboard and alert on `TCPReqQFullDrop`, `ListenOverflows`, `SyncookiesSent`.

```bash
# Reference: nftables SYNPROXY sketch (validate in staging first; this repo ships no script for it)
# nft add rule inet filter input tcp dport 443 ct state invalid counter drop
# nft add rule inet filter input tcp dport 443 tcp flags & (fin|syn|rst|ack) == syn \
#   ct state untracked counter synproxy mss 1460 wscale 7 timestamp sack-perm
```

> Those rules change firewall state. The audit script here changes nothing; apply changes through your change-management process.

## 8. Two-minute summary

- A SYN flood is a **queue** attack: no ACK, and the server holds the slot for ~31 seconds.
- Two queues: **SYN queue** (`tcp_max_syn_backlog`) and **accept queue** (`min(listen backlog, somaxconn)`). `Recv-Q` in `ss -lnt` is the latter.
- SYN cookies **validate by computation instead of storing state**, at the cost of some MSS/option negotiation.
- Watch `TCPReqQFullDrop`, `ListenOverflows`, `SyncookiesSent`. **There is no `TcpExtSYNdrop` counter.**
- A bigger backlog buys time only. Design with a front SYN proxy, XDP and anycast.

## Sources

- RFC 9293 — Transmission Control Protocol (TCP): https://www.rfc-editor.org/rfc/rfc9293.html
- RFC 4987 — TCP SYN Flooding Attacks and Common Mitigations: https://www.rfc-editor.org/rfc/rfc4987.html
- Linux kernel — ip-sysctl (`tcp_syncookies`, `tcp_max_syn_backlog`, `tcp_synack_retries`, `somaxconn`): https://docs.kernel.org/networking/ip-sysctl.html
- iproute2 — `ss(8)`, `nstat(8)`: https://man7.org/linux/man-pages/man8/ss.8.html · https://man7.org/linux/man-pages/man8/nstat.8.html
- netfilter — SYNPROXY: https://docs.kernel.org/networking/netfilter-synproxy.html

Checked on 2026-11-27. Defaults vary by kernel version, distribution and container runtime. The numbers above are from the example host — verify on the target before applying.
