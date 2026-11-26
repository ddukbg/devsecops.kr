#!/usr/bin/env bash
# check_agent_gateway_usage.sh — AI 에이전트 게이트웨이 전환 점검, 읽기 전용
#
# 배경:
#   Google Workspace AI Tools Addendum 은 2027-02-01 부터 AI 에이전트가
#   Workspace REST API 를 직접 호출하는 것을 막고 MCP 서버·CLI 만 허용합니다.
#   강제 이후 REST 직결 호출은 티어와 무관하게 Standard 쿼터(5,000건/일/프로젝트/제품)로
#   제한되므로, 사내 코드에서 "에이전트가 REST 를 직접 때리는 경로"를 먼저 찾아야 합니다.
#   AWS ELB for Envoy 는 GA(2026-11-25)지만 서울 리전이 없고 Lua·Wasm 제약이 있어
#   도입 전에 현재 구성을 읽어 두는 편이 좋습니다.
#
# 이 스크립트가 읽는 것 (모두 읽기 전용, 쓰기 호출 없음):
#   1. 소스에서 Workspace REST 직접 호출 흔적(엔드포인트·클라이언트 라이브러리)
#   2. MCP / Workspace CLI 사용 흔적
#   3. (--kube) Envoy Gateway GatewayClass 와 EnvoyProxy 리소스, envoy 이미지 파드
#   4. 로컬 도구 존재 여부(aws elb-proxy, gcloud) — 정보성
#
# 사용법:
#   bash check_agent_gateway_usage.sh
#   bash check_agent_gateway_usage.sh --dir ./src
#   bash check_agent_gateway_usage.sh --dir . --kube --context prod
#   bash check_agent_gateway_usage.sh --dir . --csv > agent_gateway_audit.csv
#   bash check_agent_gateway_usage.sh --dir . --strict      # 위험 항목이 있으면 종료코드 1
#   bash check_agent_gateway_usage.sh --dir . --skip-kube
#
# 필요: bash 3.2 이상, grep. 클러스터 점검 시 kubectl(읽기 전용 get/list).
#       jq·python 등 외부 텍스트 도구는 쓰지 않습니다.
#
# 종료코드: 0 정상, 1 --strict 조건 충족(위험 발견), 2 실행 환경·인자 오류
#
# 주의: grep 결과는 "흔적"입니다. 해당 호출이 실제로 AI 에이전트인지, OAuth 클라이언트가
#       에이전트 전용인지, 프로젝트 티어가 무엇인지는 Cloud 콘솔에서 확인해야 합니다.

set -uo pipefail

SRC_DIR="."
CSV=0
STRICT=0
SKIP_KUBE=0
USE_KUBE=0
KUBECTL="${KUBECTL:-kubectl}"
CONTEXT=""
MAX_HITS="${MAX_HITS:-8}"

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) SRC_DIR="${2:-}"; shift 2 ;;
    --csv) CSV=1; shift ;;
    --strict) STRICT=1; shift ;;
    --kube) USE_KUBE=1; shift ;;
    --skip-kube) SKIP_KUBE=1; shift ;;
    --context) CONTEXT="${2:-}"; shift 2 ;;
    --kubectl) KUBECTL="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

[ -d "$SRC_DIR" ] || { echo "directory not found: $SRC_DIR" >&2; exit 2; }

EXCLUDES="--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=vendor --exclude-dir=.cache --exclude=*.md --exclude=check_agent_gateway_usage.sh --exclude=agent-registry-elb-checklist.md"

FINDINGS=0
emit() {
  # emit <level> <id> <message> <count> <samples>
  level="$1"; id="$2"; msg="$3"; count="$4"; samples="$5"
  if [ "$CSV" -eq 1 ]; then
    printf '"%s","%s","%s","%s","%s"\n' "$id" "$level" "$count" "$msg" "$(printf '%s' "$samples" | tr '\n' '|' | sed 's/"/""/g')"
  else
    printf '[%-6s] %-10s %-52s %s\n' "$level" "$id" "$msg" "$count"
    if [ -n "$samples" ]; then
      printf '%s\n' "$samples" | head -n "$MAX_HITS" | sed 's/^/           /'
    fi
  fi
  case "$level" in
    HIGH|MED) [ "$count" != "0" ] && FINDINGS=$((FINDINGS + 1)) || true ;;
  esac
}

scan() {
  # scan <id> <level> <label> <regex>
  id="$1"; level="$2"; label="$3"; regex="$4"
  out=$(grep -rInE $EXCLUDES -- "$regex" "$SRC_DIR" 2>/dev/null)
  if [ -z "$out" ]; then
    emit "$level" "$id" "$label" "0" ""
  else
    n=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
    emit "$level" "$id" "$label" "$n" "$out"
  fi
}

if [ "$CSV" -eq 1 ]; then
  echo '"id","level","count","check","samples"'
else
  echo "== AI agent gateway readiness =="
  echo "source: $SRC_DIR  ·  verified against 2026-11-27 announcements"
  echo
  echo "-- A. Workspace REST 직접 호출 흔적 (2027-02-01 이후 Standard 쿼터로 제한) --"
fi

# --- A. Workspace REST direct calls -----------------------------------------
scan A1 MED  "Workspace REST endpoint (googleapis.com/*/vN)" \
  "googleapis\.com/(gmail|drive|calendar|sheets|docs|slides|chat|tasks)/v[0-9]"
scan A2 MED  "Workspace REST host (gmail/drive/…) without version" \
  "(gmail|drive|calendar|admin|people)\.googleapis\.com"
scan A3 MED  "OAuth token endpoint used by a custom client" \
  "oauth2\.googleapis\.com/(token|revoke)"
scan A4 LOW  "Google API client library (migration surface)" \
  "(google-api-python-client|google\.apiclient|googleapis@|@googleapis/|googleapis\.google\.com)"
scan A5 LOW  "Service-account / credential file reference" \
  "(client_secret\.json|GOOGLE_APPLICATION_CREDENTIALS|service[_-]account.*\.json)"

if [ "$CSV" -eq 0 ]; then
  echo
  echo "-- B. MCP / Workspace CLI 사용 흔적 (전환 완료 신호) --"
fi
scan B1 LOW  "MCP server reference near workspace" \
  "(workspace[^\"']{0,20}mcp|mcp[^\"']{0,20}workspace)"
scan B2 LOW  "MCP client / SDK dependency" \
  "(modelcontextprotocol|@modelcontextprotocol/|mcp-server-|fastmcp)"

# --- C. Cluster (optional) ---------------------------------------------------
if [ "$USE_KUBE" -eq 1 ] && [ "$SKIP_KUBE" -eq 0 ]; then
  if [ "$CSV" -eq 0 ]; then
    echo
    echo "-- C. 클러스터 Envoy Gateway 구성 (읽기 전용 get) --"
  fi
  CTX_ARGS=""
  [ -n "$CONTEXT" ] && CTX_ARGS="--context $CONTEXT"

  if ! command -v "$KUBECTL" >/dev/null 2>&1; then
    emit INFO C0 "$KUBECTL not found — 클러스터 점검 건너뜀" "0" ""
  else
    gc=$($KUBECTL $CTX_ARGS get gatewayclass -o name 2>/dev/null)
    gc_envoy=$(printf '%s\n' "$gc" | grep -c 'gatewayclass' 2>/dev/null || true)
    detail=$($KUBECTL $CTX_ARGS get gatewayclass -o custom-columns=NAME:.metadata.name,CTRL:.spec.controllerName --no-headers 2>/dev/null | grep 'envoyproxy.io' || true)
    if [ -n "$detail" ]; then
      n=$(printf '%s\n' "$detail" | wc -l | tr -d ' ')
      emit LOW C1 "Envoy Gateway GatewayClass 발견" "$n" "$detail"
    else
      emit INFO C1 "Envoy Gateway GatewayClass 없음" "0" ""
    fi

    ep=$($KUBECTL $CTX_ARGS get envoyproxy -A --no-headers 2>/dev/null)
    if [ -n "$ep" ]; then
      n=$(printf '%s\n' "$ep" | wc -l | tr -d ' ')
      emit LOW C2 "EnvoyProxy 리소스(self-managed 프록시 후보)" "$n" "$ep"
    else
      emit INFO C2 "EnvoyProxy 리소스 없음(CRD 미설치 포함)" "0" ""
    fi

    pods=$($KUBECTL $CTX_ARGS get pods -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,IMG:.spec.containers[*].image --no-headers 2>/dev/null | grep -i 'envoy' || true)
    if [ -n "$pods" ]; then
      n=$(printf '%s\n' "$pods" | wc -l | tr -d ' ')
      emit LOW C3 "envoy 이미지 파드" "$n" "$pods"
    else
      emit INFO C3 "envoy 이미지 파드 없음" "0" ""
    fi
  fi
fi

# --- D. Local tooling (informational) ---------------------------------------
if [ "$CSV" -eq 0 ]; then
  echo
  echo "-- D. 로컬 도구 (정보성) --"
fi
if command -v aws >/dev/null 2>&1; then
  if aws elb-proxy help >/dev/null 2>&1; then
    emit INFO D1 "aws elb-proxy 사용 가능(ELB for Envoy CLI)" "1" ""
  else
    emit INFO D1 "aws CLI 있음 · elb-proxy 미지원(버전 업데이트 필요)" "0" ""
  fi
else
  emit INFO D1 "aws CLI 없음" "0" ""
fi

if [ "$CSV" -eq 0 ]; then
  echo
  echo "-- 참고 --"
  echo "서울 리전은 ELB for Envoy GA 14개 리전에 없습니다. 도쿄·싱가포르 사용 시 RTT·데이터 레지던시를 계산하세요."
  echo "MCP Standard 한도는 5,000건/일/프로젝트/제품이며, 내부용 예외로는 MCP 쿼터를 늘릴 수 없습니다."
  echo "grep 결과는 흔적입니다. OAuth 클라이언트 유형·프로젝트 티어는 Cloud 콘솔에서 확인하세요."
  echo
  if [ "$FINDINGS" -eq 0 ]; then
    echo "결과: HIGH/MED 항목 없음 (INFO/LOW 만 존재)"
  else
    echo "결과: 확인 필요 항목 ${FINDINGS}건 (HIGH/MED)"
  fi
fi

if [ "$STRICT" -eq 1 ] && [ "$FINDINGS" -gt 0 ]; then
  exit 1
fi
exit 0
