#!/usr/bin/env bash
# check_syn_backlog.sh — TCP SYN 대기열(SYN queue) · accept queue 상태 점검, 읽기 전용
#
# 배경:
#   SYN Flood 는 대역폭 공격이 아니라 대기열 공격입니다. 클라이언트가 SYN 만 보내고
#   ACK 를 보내지 않으면 서버는 SYN-ACK 를 재전송하며 half-open 상태를 큐에 쌓습니다.
#   이 큐(SYN queue)가 차면 정상 클라이언트의 SYN 이 버려지고, accept queue 가 차면
#   이미 성립된 연결도 애플리케이션이 가져가지 못합니다.
#
# 이 스크립트가 읽는 것 (모두 읽기 전용, 어떤 값도 바꾸지 않음):
#   1. 커널·배포판 정보
#   2. 관련 sysctl 현재 값 — tcp_syncookies · tcp_max_syn_backlog · somaxconn ·
#      tcp_synack_retries · tcp_abort_on_overflow · netdev_max_backlog
#   3. LISTEN 소켓별 accept queue 사용량 (`ss -lntH`)
#   4. SYN/accept 큐 관련 커널 카운터 (`nstat`)
#
# 사용법:
#   bash check_syn_backlog.sh
#   bash check_syn_backlog.sh --csv > syn_audit.csv
#   bash check_syn_backlog.sh --strict     # 위험 항목이 있으면 종료코드 1
#   bash check_syn_backlog.sh --port 443   # 특정 포트만 표시
#
# 필요:
#   bash 3.2 이상, ss(iproute2). nstat(iproute2)와 sysctl 은 없으면 /proc 로 대체합니다.
#   root 가 아니어도 대부분 읽을 수 있지만, 일부 커널은 카운터 접근에 권한이 필요합니다.
#
# 종료코드: 0 정상, 1 --strict 조건 충족(위험 발견), 2 실행 환경·인자 오류

set -uo pipefail

CSV=0
STRICT=0
ONLY_PORT=""
RISK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --csv) CSV=1 ;;
    --strict) STRICT=1 ;;
    --port) shift; ONLY_PORT="${1:-}" ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "알 수 없는 인자: $1 (--help 참고)" >&2; exit 2 ;;
  esac
  shift
done

# ── 출력 도우미 ──────────────────────────────────────────────────────────────
csv_row() { [ "$CSV" = 1 ] && printf '%s\n' "$(IFS=,; echo "$*")"; }
section() { [ "$CSV" = 1 ] && printf '\n# %s\n' "$1" || { printf '\n== %s ==\n' "$1"; }; }
row()     { [ "$CSV" = 1 ] && csv_row "$@" || printf '%-34s %-10s %s\n' "$1" "$2" "$3"; }

risk() { RISK=$((RISK + 1)); }

# sysctl 읽기: sysctl 이 있으면 쓰고, 없으면 /proc/sys 에서 읽는다(둘 다 읽기 전용).
read_sysctl() {
  local key="$1" path val
  path="/proc/sys/$(echo "$key" | tr '.' '/')"
  if command -v sysctl >/dev/null 2>&1; then
    val=$(sysctl -n "$key" 2>/dev/null) && [ -n "$val" ] && { printf '%s' "$val"; return 0; }
  fi
  [ -r "$path" ] && { tr -d '[:space:]' < "$path"; return 0; }
  printf 'N/A'
  return 1
}

# ── 1. 시스템 ───────────────────────────────────────────────────────────────
section "1. 시스템"
if [ "$CSV" = 1 ]; then
  csv_row "kernel" "$(uname -r)"
  [ -r /etc/os-release ] && csv_row "os" "$(. /etc/os-release; echo "${PRETTY_NAME:-unknown}")"
  csv_row "checked_at" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
else
  printf '%-34s %s\n' "kernel" "$(uname -r)"
  [ -r /etc/os-release ] && printf '%-34s %s\n' "os" "$(. /etc/os-release; echo "${PRETTY_NAME:-unknown}")"
  printf '%-34s %s\n' "checked_at" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
fi

# ── 2. sysctl ───────────────────────────────────────────────────────────────
section "2. 관련 sysctl (읽기 전용)"

# tcp_syncookies: 0=끔, 1=큐가 넘칠 때만, 2=항상
SYNCOOKIES=$(read_sysctl net.ipv4.tcp_syncookies)
MAXSYN=$(read_sysctl net.ipv4.tcp_max_syn_backlog)
SOMAX=$(read_sysctl net.core.somaxconn)
SYNACK=$(read_sysctl net.ipv4.tcp_synack_retries)
ABORT=$(read_sysctl net.ipv4.tcp_abort_on_overflow)
NETDEV=$(read_sysctl net.core.netdev_max_backlog)

case "$SYNCOOKIES" in
  0) SC_VERDICT="RISK (쿠키 꺼짐)"; risk ;;
  1) SC_VERDICT="OK (필요 시 사용)" ;;
  2) SC_VERDICT="OK (항상 사용)" ;;
  *) SC_VERDICT="VERIFY"; risk ;;
esac
row "net.ipv4.tcp_syncookies" "$SYNCOOKIES" "$SC_VERDICT"

case "$MAXSYN" in
  N/A) MX_VERDICT="VERIFY"; risk ;;
  *) if [ "$MAXSYN" -lt 512 ] 2>/dev/null; then MX_VERDICT="LOW (512 미만)"; risk
     elif [ "$MAXSYN" -lt 1024 ] 2>/dev/null; then MX_VERDICT="VERIFY (1024 미만)"
     else MX_VERDICT="OK"; fi ;;
esac
row "net.ipv4.tcp_max_syn_backlog" "$MAXSYN" "$MX_VERDICT → SYN queue 상한"

case "$SOMAX" in
  N/A) SO_VERDICT="VERIFY"; risk ;;
  *) if [ "$SOMAX" -lt 1024 ] 2>/dev/null; then SO_VERDICT="LOW (1024 미만)"; risk
     else SO_VERDICT="OK"; fi ;;
esac
row "net.core.somaxconn" "$SOMAX" "$SO_VERDICT → accept queue 상한(listen 백로그와 min)"

row "net.ipv4.tcp_synack_retries" "$SYNACK" "SYN-ACK 재전송 횟수(기본 5 ≈ 31초 대기)"
row "net.ipv4.tcp_abort_on_overflow" "$ABORT" "1이면 오버플로 시 RST(기본 0=조용히 버림)"
row "net.core.netdev_max_backlog" "$NETDEV" "NIC 수신 큐(별도 계층)"

# ── 3. LISTEN 소켓 ──────────────────────────────────────────────────────────
section "3. LISTEN 소켓 (ss -lntH)"
if ! command -v ss >/dev/null 2>&1; then
  row "ss" "MISSING" "iproute2 미설치 — 이 절을 건너뜁니다"
  risk
else
  SS_OUT=$(ss -lntH 2>/dev/null)
  PENDING=0
  LISTENERS=0
  if [ "$CSV" = 1 ]; then csv_row "state" "recv_q(accept 대기)" "send_q(상한)" "local"; else
    printf '%-6s %-18s %-12s %s\n' "STATE" "RECV-Q(대기)" "SEND-Q(상한)" "LOCAL"
  fi
  while read -r state recvq sendq local rest; do
    [ -z "${state:-}" ] && continue
    case "$ONLY_PORT" in "") ;; *) case "$local" in *":$ONLY_PORT") ;; *) continue ;; esac ;; esac
    LISTENERS=$((LISTENERS + 1))
    [ "${recvq:-0}" -gt 0 ] 2>/dev/null && PENDING=$((PENDING + recvq))
    if [ "$CSV" = 1 ]; then
      csv_row "$state" "$recvq" "$sendq" "$local"
    else
      mark=""
      [ "${recvq:-0}" -gt 0 ] 2>/dev/null && mark="  ← accept queue 사용 중"
      printf '%-6s %-18s %-12s %s%s\n' "$state" "$recvq" "$sendq" "$local" "$mark"
    fi
  done <<< "$SS_OUT"

  if [ "$CSV" != 1 ]; then
    printf '\n%-34s %s\n' "LISTEN 소켓 수" "$LISTENERS"
    printf '%-34s %s\n' "accept queue 대기 합계" "$PENDING"
    if [ "$PENDING" -gt 0 ] 2>/dev/null; then
      printf '  → 지속적으로 0이 아니면 애플리케이션이 accept 를 못 따라가는 상태입니다.\n'
      risk
    fi
  fi
fi

# ── 4. 커널 카운터 ──────────────────────────────────────────────────────────
section "4. SYN·accept 큐 커널 카운터 (nstat, 부팅 이후 누적)"
# TcpExtSYNdrop 은 메인라인 커널 카운터 이름이 아닙니다. SYN 큐 포화 신호는
# TCPReqQFullDrop / TCPReqQFullDoCookies / ListenOverflows 로 나옵니다.
# 요청에 따라 TcpExtSYNdrop 도 함께 조회하되, 없으면 N/A 로 표시합니다.
COUNTERS="TcpExtSYNdrop TcpExtTCPReqQFullDrop TcpExtTCPReqQFullDoCookies TcpExtListenOverflows TcpExtListenDrops TcpExtSyncookiesSent TcpExtSyncookiesRecv TcpExtSyncookiesFailed TcpExtEmbryonicRsts"

if ! command -v nstat >/dev/null 2>&1 && [ ! -r /proc/net/netstat ]; then
  row "nstat" "MISSING" "iproute2·/proc/net/netstat 접근 불가 — 이 절을 건너뜁니다"
else
  NSTAT_OUT=$(nstat -az $COUNTERS 2>/dev/null)
  [ -z "$NSTAT_OUT" ] && [ -r /proc/net/netstat ] && NSTAT_OUT=$(nstat -az 2>/dev/null)

  if [ "$CSV" = 1 ]; then csv_row "counter" "value" "note"; else
    printf '%-30s %-12s %s\n' "COUNTER" "VALUE" "NOTE"
  fi
  for c in $COUNTERS; do
    v=""
    while read -r cname cval _rest; do
      [ "$cname" = "$c" ] && { v="$cval"; break; }
    done <<< "$NSTAT_OUT"
    note=""
    case "$c" in
      TcpExtSYNdrop) [ -z "$v" ] && note="이 커널에 없는 카운터(메인라인 미제공)" ;;
      TcpExtTCPReqQFullDrop) [ -n "$v" ] && [ "${v:-0}" -gt 0 ] 2>/dev/null && { note="SYN queue 포화로 드롭"; risk; } ;;
      TcpExtListenOverflows) [ -n "$v" ] && [ "${v:-0}" -gt 0 ] 2>/dev/null && { note="accept queue 오버플로"; risk; } ;;
      TcpExtListenDrops) [ -n "$v" ] && [ "${v:-0}" -gt 0 ] 2>/dev/null && note="accept 단계 드롭(위 항목 포함)" ;;
      TcpExtSyncookiesSent) [ -n "$v" ] && [ "${v:-0}" -gt 0 ] 2>/dev/null && note="SYN cookie 로 응답한 횟수(방어 동작)" ;;
      *) ;;
    esac
    row "$c" "${v:-N/A}" "$note"
  done
fi

# ── 5. 요약 ─────────────────────────────────────────────────────────────────
section "요약"
if [ "$RISK" -eq 0 ]; then
  [ "$CSV" = 1 ] && csv_row "verdict" "OK" "risk=0" || printf '위험 항목 0건 — syncookies·백로그·accept queue 모두 기본값 이상입니다.\n'
else
  [ "$CSV" = 1 ] && csv_row "verdict" "ATTENTION" "risk=$RISK" || printf '확인이 필요한 항목 %s건. 위 표의 RISK·VERIFY 행을 먼저 보세요.\n' "$RISK"
fi
[ "$CSV" = 1 ] || printf '\n읽기 전용 점검입니다. 값을 바꾸지 않았습니다. 조치 순서는 README 7절을 참고하세요.\n'

[ "$STRICT" = 1 ] && [ "$RISK" -gt 0 ] && exit 1
exit 0
