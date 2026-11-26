#!/usr/bin/env bash
# check_kyverno_parser.sh — GHSA-pcx2-xcq4-65vf (Kyverno apiCall URL 파서 불일치) 노출 점검, 읽기 전용
#
# 배경:
#   Kyverno 1.19.2 미만의 pkg/engine/apicall/apiCall.go Fetch() 는 URLPath 를
#   path.Clean(파일 경로 함수)으로 정리한 뒤 정규식으로 네임스페이스를 뽑았습니다.
#   실행 단계의 client-go 는 같은 문자열을 net/url 로 파싱해 '?' 뒤를 쿼리로 잘라냅니다.
#   그래서 urlPath "/api/v1/nodes?x=/namespaces/default/" 는 검증을 통과하고
#   실제로는 클러스터 전역 /api/v1/nodes 로 요청됩니다.
#
# 이 스크립트가 읽는 것 (모두 읽기 전용, 쓰기 호출 없음):
#   1. 클러스터의 Kyverno 워크로드 이미지 태그 — 1.19.2 미만 여부
#   2. 네임스페이스 Policy(policies.kyverno.io) 목록과 apiCall 사용 여부
#   3. urlPath 에 '?'·'#'·%3F·%23 처럼 네임스페이스를 숨길 수 있는 decoy 가 있는지
#   4. 로컬 소스의 path.Clean · normpath( · startswith("/") 패턴
#
# 사용법:
#   bash check_kyverno_parser.sh
#   bash check_kyverno_parser.sh --context prod --dir ./src
#   bash check_kyverno_parser.sh --csv > kyverno_audit.csv
#   bash check_kyverno_parser.sh --strict        # 위험 항목이 있으면 종료코드 1
#   bash check_kyverno_parser.sh --skip-cluster --dir .
#
# 필요:
#   kubectl(클러스터 점검 시). jq·awk·python 등 외부 텍스트 도구는 쓰지 않습니다(bash 3.2 이상).
#   최소 권한(읽기): get/list deployments, policies.kyverno.io
#   Kyverno CRD 가 없거나 권한이 없으면 해당 절만 건너뜁니다.
#
# 종료코드: 0 정상, 1 --strict 조건 충족(위험 발견), 2 실행 환경·인자 오류

set -uo pipefail

FIXED_VERSION="1.19.2"
KUBECTL="${KUBECTL:-kubectl}"
CONTEXT=""
KUBECONFIG_PATH=""
SRC_DIR="."
CSV=0
STRICT=0
SKIP_CLUSTER=0
SKIP_SOURCE=0
MAX_POLICIES=300

usage() {
  cat <<'EOF'
사용법: bash check_kyverno_parser.sh [옵션]

  --context NAME     kubectl context 지정
  --kubeconfig PATH  kubeconfig 파일 지정
  --dir PATH         소스 검색 경로 (기본: 현재 디렉터리)
  --csv              표 대신 CSV 출력 (요약은 stderr)
  --strict           위험 항목이 있으면 종료코드 1
  --skip-cluster     클러스터 점검 생략 (소스만)
  --skip-source      소스 점검 생략 (클러스터만)
  --kubectl PATH     kubectl 대체 실행 파일 (테스트용)
  -h, --help         이 도움말

판정 코드:
  ACT_NOW      Kyverno 1.19.2 미만 — 즉시 업그레이드
  OK           해당 없음
  VERIFY       태그 해석 불가(latest·digest·태그 없음) — 콘솔에서 확인
  DECOY        urlPath 의 쿼리·fragment 에 /namespaces/ 문자열 (우회 시도 형태)
  USES_APICALL apiCall 사용, decoy 없음 — 정책 작성 권한 통제 대상
  SKIP         CRD 없음·권한 없음·조회 실패
EOF
}

die() { printf '오류: %s\n' "$1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --context)      [ $# -ge 2 ] || die "--context 값이 없습니다"; CONTEXT="$2"; shift 2 ;;
    --kubeconfig)   [ $# -ge 2 ] || die "--kubeconfig 값이 없습니다"; KUBECONFIG_PATH="$2"; shift 2 ;;
    --dir)          [ $# -ge 2 ] || die "--dir 값이 없습니다"; SRC_DIR="$2"; shift 2 ;;
    --csv)          CSV=1; shift ;;
    --strict)       STRICT=1; shift ;;
    --skip-cluster) SKIP_CLUSTER=1; shift ;;
    --skip-source)  SKIP_SOURCE=1; shift ;;
    --kubectl)      [ $# -ge 2 ] || die "--kubectl 값이 없습니다"; KUBECTL="$2"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              usage >&2; die "알 수 없는 옵션: $1" ;;
  esac
done

KUBE_ARGS=""
[ -n "$CONTEXT" ] && KUBE_ARGS="$KUBE_ARGS --context $CONTEXT"
[ -n "$KUBECONFIG_PATH" ] && KUBE_ARGS="$KUBE_ARGS --kubeconfig $KUBECONFIG_PATH"

kc() { $KUBECTL --request-timeout=20s $KUBE_ARGS "$@"; }

TMP="$(mktemp -t kyverno_audit.XXXXXX)" || die "임시 파일을 만들 수 없습니다"
trap 'rm -f "$TMP" "$TMP.err"' EXIT
: >"$TMP.err"

RISK=0

# ---------------------------------------------------------------------------
# 버전 비교 (semver major.minor.patch, 프리릴리스는 별도 표시)
# ---------------------------------------------------------------------------
V_MAJOR=""; V_MINOR=""; V_PATCH=""; V_PRE=""

parse_core() {
  local v="${1#v}"
  v="${v%%+*}"
  V_PRE=""
  case "$v" in
    *-*) V_PRE="${v#*-}"; v="${v%%-*}" ;;
  esac
  V_MAJOR="${v%%.*}"
  local rest="${v#*.}"
  [ "$rest" = "$v" ] && rest="0"
  V_MINOR="${rest%%.*}"
  local last="0"
  case "$rest" in
    *.*) last="${rest#*.}"; last="${last%%.*}" ;;
  esac
  V_PATCH="$last"
  case "$V_MAJOR$V_MINOR$V_PATCH" in
    ''|*[!0-9]*) return 1 ;;
  esac
  return 0
}

# 결과를 stdout 으로: -1 / 0 / 1 / 9(해석 불가)
ver_cmp() {
  parse_core "$1" || { echo 9; return; }
  local a1="$V_MAJOR" a2="$V_MINOR" a3="$V_PATCH"
  parse_core "$2" || { echo 9; return; }
  local b1="$V_MAJOR" b2="$V_MINOR" b3="$V_PATCH"
  if [ "$a1" -ne "$b1" ]; then
    [ "$a1" -lt "$b1" ] && echo -1 || echo 1
  elif [ "$a2" -ne "$b2" ]; then
    [ "$a2" -lt "$b2" ] && echo -1 || echo 1
  elif [ "$a3" -ne "$b3" ]; then
    [ "$a3" -lt "$b3" ] && echo -1 || echo 1
  else
    echo 0
  fi
}

verdict_for_version() {
  local ver="$1" cmp
  cmp="$(ver_cmp "$ver" "$FIXED_VERSION")"
  case "$cmp" in
    -1) echo "ACT_NOW" ;;
    0)
      parse_core "$ver"
      if [ -n "$V_PRE" ]; then echo "VERIFY"; else echo "OK"; fi ;;
    1)  echo "OK" ;;
    *)  echo "VERIFY" ;;
  esac
}

# 이미지 문자열에서 태그만 추출 (registry:port, digest 처리)
tag_of_image() {
  local img="${1%%@*}"
  case "$img" in
    *:*) local t="${img##*:}"
         case "$t" in */*) echo "" ;; *) echo "$t" ;; esac ;;
    *)   echo "" ;;
  esac
}

# ---------------------------------------------------------------------------
# 1. 클러스터: Kyverno 버전
# ---------------------------------------------------------------------------
print_table_header() {
  printf '%-12s %-30s %-54s %s\n' "NAMESPACE" "WORKLOAD" "IMAGE (VERSION)" "VERDICT"
}

check_cluster_version() {
  local raw
  raw="$(kc get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"|"}{.metadata.name}{"|"}{range .spec.template.spec.containers[*]}{.image}{","}{end}{"\n"}{end}' 2>>"$TMP.err")"

  if [ -z "$raw" ]; then
    printf 'SKIP|cluster|-|Kyverno Deployment 를 찾지 못했거나 조회 권한이 없습니다|SKIP\n' >>"$TMP"
    return
  fi

  local line ns name images img tag
  printf '%s\n' "$raw" | while IFS='|' read -r ns name images; do
    [ -n "$name" ] || continue
    printf '%s' "$images" | tr ',' '\n' | while IFS= read -r img; do
      [ -n "$img" ] || continue
      case "$img" in
        *kyverno*) : ;;
        *) continue ;;
      esac
      tag="$(tag_of_image "$img")"
      if [ -z "$tag" ]; then
        printf '%s|cluster|%s|%s (tag 없음)|VERIFY\n' "$ns" "$name" "$img" >>"$TMP"
      else
        printf '%s|cluster|%s|%s (%s)|%s\n' "$ns" "$name" "$img" "${tag#v}" "$(verdict_for_version "$tag")" >>"$TMP"
      fi
    done
  done
}

# ---------------------------------------------------------------------------
# 2. 클러스터: 네임스페이스 Policy 의 apiCall / decoy
# ---------------------------------------------------------------------------
check_cluster_policies() {
  local list
  list="$(kc get policies.kyverno.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' 2>>"$TMP.err")"

  if [ -z "$list" ]; then
    if grep -qi 'the server doesn.t have a resource type' "$TMP.err" 2>/dev/null; then
      printf 'SKIP|policy|-|policies.kyverno.io CRD 없음 (Kyverno 미설치?)|SKIP\n' >>"$TMP"
    else
      printf 'SKIP|policy|-|Policy 목록을 읽지 못했습니다 (권한 또는 접속 확인)|SKIP\n' >>"$TMP"
    fi
    return
  fi

  local count=0 ns_name ns name yaml urlpaths verdict detail
  printf '%s\n' "$list" | while IFS= read -r ns_name; do
    [ -n "$ns_name" ] || continue
    count=$((count + 1))
    if [ "$count" -gt "$MAX_POLICIES" ]; then
      printf 'SKIP|policy|%s|정책이 %s개를 넘어 나머지는 건너뜀|SKIP\n' "$ns_name" "$MAX_POLICIES" >>"$TMP"
      break
    fi
    ns="${ns_name%%/*}"
    name="${ns_name#*/}"
    yaml="$(kc get policies.kyverno.io "$name" -n "$ns" -o yaml 2>/dev/null)"
    [ -n "$yaml" ] || continue

    if ! printf '%s\n' "$yaml" | grep -q 'apiCall:'; then
      continue
    fi

    urlpaths="$(printf '%s\n' "$yaml" | grep -E '^[[:space:]]*urlPath:' | sed -e 's/^[[:space:]]*//')"
    verdict="USES_APICALL"
    detail="apiCall 사용"
    case "$urlpaths" in
      *'?'*|*'#'*|*%3[fF]*|*%23*)
        verdict="DECOY"
        detail="$urlpaths" ;;
      *) [ -n "$urlpaths" ] && detail="$urlpaths" ;;
    esac
    printf '%s|policy|%s|%s|%s\n' "$ns" "$ns/$name" "$detail" "$verdict" >>"$TMP"
  done
}

# ---------------------------------------------------------------------------
# 3. 소스: URL 을 파일 경로 함수로 검증하는 패턴
# ---------------------------------------------------------------------------
scan_source() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    printf 'SKIP|source|%s|디렉터리 없음|SKIP\n' "$dir" >>"$TMP"
    return
  fi
  local pats hits total shown
  # url_validator_example.py 는 취약·안전 패턴을 교육용으로 함께 담고 있어 제외합니다.
  pats='path\.Clean|posixpath\.normpath|normpath\(|startswith\("/"\)'
  hits="$(grep -rnE "$pats" \
      --include='*.go' --include='*.py' --include='*.js' --include='*.ts' \
      --exclude-dir=.git --exclude-dir=vendor --exclude-dir=node_modules \
      --exclude-dir=dist --exclude-dir=build \
      --exclude='url_validator_example.py' "$dir" 2>/dev/null)"
  total=0
  [ -n "$hits" ] && total="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  if [ "$total" -eq 0 ]; then
    printf 'OK|source|%s|path.Clean·normpath·startswith 패턴 없음|OK\n' "$dir" >>"$TMP"
    return
  fi
  printf 'DECOY|source|%s|의심 패턴 %s건 — 파일 경로 함수로 URL 검증 여부 확인 필요|DECOY\n' "$dir" "$total" >>"$TMP"
  printf '%s\n' "$hits" | sed -n '1,10p' | while IFS= read -r shown; do
    printf 'INFO|source|%s|%s|INFO\n' "$dir" "${shown#"$dir"/}" >>"$TMP"
  done
}

# ---------------------------------------------------------------------------
# 실행
# ---------------------------------------------------------------------------
CLUSTER_OK=1
if [ "$SKIP_CLUSTER" -eq 0 ]; then
  if ! command -v "${KUBECTL%% *}" >/dev/null 2>&1 && [ ! -x "${KUBECTL%% *}" ]; then
    die "kubectl 을 찾을 수 없습니다. --skip-cluster 로 소스만 점검하거나 kubectl 을 설치하세요."
  fi
  if ! kc version --client >/dev/null 2>&1; then
    die "'$KUBECTL version --client' 실행 실패. --kubectl 경로를 확인하세요."
  fi
  if ! kc get --raw='/readyz' >/dev/null 2>&1; then
    printf '경고: 클러스터에 접속하지 못했습니다. 클러스터 점검을 건너뜁니다.\n' >&2
    CLUSTER_OK=0
  fi
  if [ "$CLUSTER_OK" -eq 1 ]; then
    check_cluster_version
    check_cluster_policies
  fi
fi

if [ "$SKIP_SOURCE" -eq 0 ]; then
  scan_source "$SRC_DIR"
fi

if [ ! -s "$TMP" ]; then
  printf '점검 항목이 없습니다(--skip-cluster/--skip-source 확인).\n' >&2
  exit 2
fi

# 요약 집계 (--strict 기준: 버전 ACT_NOW + 정책 DECOY. 소스 패턴은 참고 지표)
RISK_VER="$(grep -c '|ACT_NOW$' "$TMP" 2>/dev/null)"
RISK_POL="$(grep -c '|policy|.*|DECOY$' "$TMP" 2>/dev/null)"
RISK_VER="${RISK_VER:-0}"
RISK_POL="${RISK_POL:-0}"
RISK=$((RISK_VER + RISK_POL))
SOURCE_HITS="$(grep -cE '^DECOY\|source\|' "$TMP" 2>/dev/null)"
SOURCE_HITS="${SOURCE_HITS:-0}"
SKIPS="$(grep -c '|SKIP$' "$TMP" 2>/dev/null)"
SKIPS="${SKIPS:-0}"

if [ "$CSV" -eq 1 ]; then
  printf 'scope,type,name,detail,verdict\n'
  sed -e 's/|/,/g' "$TMP" | grep -v '^INFO,'
  {
    printf '\n== 요약 ==\n'
    printf '위험 %s건(Kyverno 버전 %s · 정책 decoy %s) · 소스 의심 패턴 %s · 건너뜀 %s건\n' \
      "$RISK" "$RISK_VER" "$RISK_POL" "$SOURCE_HITS" "$SKIPS"
  } >&2
else
  printf '\n== 1. Kyverno 버전 ==\n'
  if grep -q '|cluster|' "$TMP"; then
    print_table_header
    grep '|cluster|' "$TMP" | while IFS='|' read -r a b c d e; do
      if [ "$e" = "SKIP" ]; then
        printf '[SKIP] %s\n' "$d"
      else
        printf '%-12s %-30s %-54s %s\n' "$a" "$c" "$d" "$e"
      fi
    done
  else
    printf '(점검하지 못했습니다)\n'
  fi

  printf '\n== 2. 네임스페이스 Policy 의 apiCall ==\n'
  if grep -q '|policy|' "$TMP"; then
    grep '|policy|' "$TMP" | while IFS='|' read -r a b c d e; do
      if [ "$e" = "SKIP" ]; then
        printf '[SKIP] %s\n' "$d"
      else
        printf '%-11s %-30s %s\n' "$e" "$c" "$d"
      fi
    done
  else
    printf 'apiCall 을 쓰는 네임스페이스 Policy 가 없습니다.\n'
  fi

  if grep -q '|source|' "$TMP"; then
    printf '\n== 3. 소스 패턴 ==\n'
    grep '|source|' "$TMP" | while IFS='|' read -r a b c d e; do
      if [ "$a" = "INFO" ]; then
        printf '  · %s\n' "$d"
      else
        printf '[%s] %s — %s\n' "$e" "$c" "$d"
      fi
    done
  fi

  printf '\n== 요약 ==\n'
  printf '위험 %s건(버전 %s · 정책 decoy %s) · 소스 의심 패턴 %s · 건너뜀 %s건 (기준: Kyverno %s 미만)\n' \
    "$RISK" "$RISK_VER" "$RISK_POL" "$SOURCE_HITS" "$SKIPS" "$FIXED_VERSION"
  if grep -q 'ACT_NOW' "$TMP"; then
    printf '→ Kyverno 를 %s 이상으로 업그레이드하세요.\n' "$FIXED_VERSION"
  fi
  if grep -q '|policy|.*|DECOY$' "$TMP"; then
    printf '→ urlPath 에 /namespaces/ decoy 가 있는 Policy 를 작성자와 함께 확인하세요.\n'
  fi
fi

if [ ! -s "$TMP.err" ]; then
  :
else
  printf '\n(참고) kubectl 진단 메시지:\n' >&2
  sed -n '1,5p' "$TMP.err" >&2
fi

if [ "$STRICT" -eq 1 ] && [ "$RISK" -gt 0 ]; then
  exit 1
fi
exit 0
