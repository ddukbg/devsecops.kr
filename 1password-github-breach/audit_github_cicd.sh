#!/usr/bin/env bash
# audit_github_cicd.sh — GitHub · CI/CD 공급망 통제 점검 (읽기 전용)
#
# 1Password 직원 기업 GitHub 계정 침해(2026-11-19 탐지 · 2026-11-25 공개) 사례를 기준으로
#   - 기본 브랜치 보호 (승인 수 · CODEOWNERS · 커밋 서명 · 강제 푸시 · 관리자 예외)
#   - rulesets
#   - Actions 기본 토큰 권한 · 워크플로 파일의 정적 키/OIDC/pull_request_target
#   - 저장소·환경·조직 시크릿 이름과 갱신일 (값은 조회 불가)
#   - 배포 환경의 수동 승인 게이트
#   - 배포 키
#   - 조직 Fine-Grained PAT · SSO 자격증명
# 을 조회만 합니다. 쓰기 API는 호출하지 않으며 저장소·조직 설정을 변경하지 않습니다.
#
# 사용법:
#   bash audit_github_cicd.sh ORG/REPO
#   bash audit_github_cicd.sh ORG/REPO --branch main --branch release
#   bash audit_github_cicd.sh ORG/REPO --strict     # 주의 항목이 있으면 종료코드 1
#
# 필요:
#   gh CLI 로그인 (repo, read:org 권장). 조직 단위 조회는 조직 관리자 권한이 필요하며,
#   권한이 없으면 해당 항목을 [미확인]으로 표시하고 계속 진행합니다.
#   jq는 필요하지 않습니다 (gh api --jq 사용).
set -euo pipefail

usage() {
  cat <<'EOF'
사용법: bash audit_github_cicd.sh ORG/REPO [--branch NAME]... [--strict]

  ORG/REPO     점검할 저장소 (예: myorg/myrepo)
  --branch     추가로 점검할 브랜치 (기본 브랜치 외, 여러 번 지정 가능)
  --strict     [주의] 항목이 하나라도 있으면 종료코드 1로 끝냄 (기본 0)

이 스크립트는 읽기 전용이며 시스템·저장소 설정을 변경하지 않습니다.
EOF
}

if [ "$#" -lt 1 ]; then usage >&2; exit 2; fi
case "$1" in -h|--help) usage; exit 0 ;; esac

REPO_SLUG="$1"; shift
case "$REPO_SLUG" in
  */*) ;;
  *) echo "ORG/REPO 형식으로 지정하세요 (예: myorg/myrepo)." >&2; exit 2 ;;
esac
REPO_SLUG="${REPO_SLUG#/}"
REPO_SLUG="${REPO_SLUG%/}"
ORG="${REPO_SLUG%%/*}"
REPO="${REPO_SLUG##*/}"

BRANCHES=()
STRICT=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --branch)
      if [ "$#" -lt 2 ]; then echo "--branch 뒤에 브랜치 이름이 필요합니다." >&2; exit 2; fi
      BRANCHES+=("$2"); shift 2 ;;
    --branch=*)
      BRANCHES+=("${1#--branch=}"); shift ;;
    --strict)
      STRICT=1; shift ;;
    *)
      echo "알 수 없는 인자: $1" >&2; exit 2 ;;
  esac
done

WARN=0
UNK=0
ok()   { printf '[OK]     %s\n' "$*"; }
warn() { WARN=$((WARN + 1)); printf '[주의]   %s\n' "$*"; }
unk()  { UNK=$((UNK + 1)); printf '[미확인] %s\n' "$*"; }
info() { printf '         %s\n' "$*"; }
head1() { printf '\n== %s ==\n' "$*"; }

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI가 필요합니다: https://cli.github.com" >&2
  exit 2
fi

ME=""
if ! ME="$(gh api user --jq .login 2>/dev/null)"; then
  echo "gh 인증에 실패했습니다. 'gh auth login' 후 다시 실행하세요." >&2
  exit 2
fi

head1 "0. 환경"
printf '         gh       : %s\n' "$(gh --version | head -n 1)"
printf '         로그인   : %s\n' "$ME"
printf '         대상     : %s\n' "$REPO_SLUG"

head1 "1. 저장소 기본 정보"
meta=""
if ! meta="$(gh api "repos/$ORG/$REPO" --jq '
    [ .full_name, .visibility, .default_branch,
      ((.archived // false) | tostring), ((.fork // false) | tostring),
      ((.permissions.admin // false) | tostring) ] | @tsv' 2>/dev/null)"; then
  echo "저장소를 조회할 수 없습니다: $REPO_SLUG (이름과 접근 권한을 확인하세요)." >&2
  exit 2
fi
IFS=$'\t' read -r FULL VISIBILITY DEF_BRANCH ARCHIVED FORKED IS_ADMIN <<<"$meta"
info "저장소: $FULL ($VISIBILITY)"
info "기본 브랜치: $DEF_BRANCH"
[ "$ARCHIVED" = "true" ] && info "보관(archived) 상태: 쓰기 불가"
[ "$FORKED" = "true" ] && info "포크 저장소"
if [ "$IS_ADMIN" != "true" ]; then
  unk "이 계정은 저장소 admin이 아닙니다. 브랜치 보호·rulesets 조회가 제한될 수 있습니다."
fi

# ---------------------------------------------------------------------------
# 2. 브랜치 보호
# ---------------------------------------------------------------------------
check_protection() {
  local br="$1" tsv err
  if tsv="$(gh api "repos/$ORG/$REPO/branches/$br/protection" --jq '
      [ ((.required_pull_request_reviews.required_approving_review_count // 0) | tostring),
        ((.required_pull_request_reviews.require_code_owner_reviews // false) | tostring),
        ((.required_pull_request_reviews.dismiss_stale_reviews // false) | tostring),
        ((.enforce_admins.enabled // false) | tostring),
        ((.required_signatures.enabled // false) | tostring),
        ((.allow_force_pushes.enabled // false) | tostring),
        ((.allow_deletions.enabled // false) | tostring),
        ((.required_linear_history.enabled // false) | tostring),
        (((.required_status_checks.contexts // []) | length) | tostring)
      ] | @tsv' 2>/dev/null)"; then
    IFS=$'\t' read -r APPROVALS CODEOWNERS _STALE ADMINS SIGS FORCEPUSH DELETIONS LINEAR CHECKS <<<"$tsv"
    printf '  브랜치 %s\n' "$br"
    if [ "$APPROVALS" -ge 2 ]; then
      ok "필수 승인 ${APPROVALS}인"
    elif [ "$APPROVALS" -eq 1 ]; then
      warn "필수 승인 1인 — 계정 하나가 뚫리면 승인 게이트가 무력화됩니다"
    else
      warn "필수 승인 없음 — 리뷰 없이 병합 가능"
    fi
    if [ "$CODEOWNERS" = "true" ]; then ok "CODEOWNERS 리뷰 필수"; else warn "CODEOWNERS 리뷰 미강제"; fi
    if [ "$SIGS" = "true" ]; then ok "커밋 서명 필수"; else warn "커밋 서명 미강제 — 탈취 계정의 커밋이 구분되지 않음"; fi
    if [ "$FORCEPUSH" = "true" ]; then warn "강제 푸시 허용 — PR 히스토리 재작성 가능"; else ok "강제 푸시 차단"; fi
    if [ "$DELETIONS" = "true" ]; then warn "브랜치 삭제 허용"; else ok "브랜치 삭제 차단"; fi
    if [ "$ADMINS" = "true" ]; then ok "관리자에게도 규칙 적용(enforce_admins)"; else warn "관리자 예외(enforce_admins=false) — 사고 시 우회 경로"; fi
    info "상태 체크 ${CHECKS}개 · 선형 히스토리 ${LINEAR} · 오래된 승인 무효화 ${_STALE}"
  else
    err="$(gh api "repos/$ORG/$REPO/branches/$br/protection" 2>&1 >/dev/null || true)"
    case "$err" in
      *"Branch not protected"*|*"404"*)
        warn "브랜치 $br: 보호 규칙 없음 — 직접 푸시·강제 푸시가 허용됩니다" ;;
      *"Resource not accessible"*|*"403"*|*"Must have admin"*)
        unk "브랜치 $br: 보호 상태 조회 불가 — 저장소 admin 권한 또는 토큰 스코프(Administration read) 부족" ;;
      *)
        unk "브랜치 $br: 보호 상태 조회 실패 — ${err%%$'\n'*}" ;;
    esac
  fi
}

head1 "2. 브랜치 보호 (기본 브랜치 · 배포 브랜치)"
check_protection "$DEF_BRANCH"
if [ "${#BRANCHES[@]}" -gt 0 ]; then
  for br in "${BRANCHES[@]}"; do
    [ "$br" = "$DEF_BRANCH" ] || check_protection "$br"
  done
fi

# ---------------------------------------------------------------------------
# 3. rulesets
# ---------------------------------------------------------------------------
head1 "3. Rulesets"
if rs="$(gh api "repos/$ORG/$REPO/rulesets?per_page=100" --jq '
    .[]? | [ (.id | tostring), .name, (.target // "-"), .enforcement ] | @tsv' 2>/dev/null)"; then
  if [ -z "$rs" ]; then
    info "rulesets 없음 (레거시 브랜치 보호만 사용 중)"
  else
    while IFS=$'\t' read -r RS_ID RS_NAME RS_TARGET RS_ENF; do
      [ -n "$RS_ID" ] || continue
      RS_TYPES="$(gh api "repos/$ORG/$REPO/rulesets/$RS_ID" --jq '[.rules[].type] | join(",")' 2>/dev/null || echo "?")"
      printf '  [%s] %s (%s, %s)\n' "$RS_ID" "$RS_NAME" "$RS_TARGET" "$RS_ENF"
      info "규칙: $RS_TYPES"
    done <<<"$rs"
  fi
else
  unk "rulesets 조회 실패 (조직 관리자 또는 저장소 admin 권한 필요)"
fi

# ---------------------------------------------------------------------------
# 4. Actions · 워크플로 토큰 권한
# ---------------------------------------------------------------------------
head1 "4. Actions · 워크플로 기본 토큰 권한"
if ap="$(gh api "repos/$ORG/$REPO/actions/permissions" --jq '
    [ ((.enabled // false) | tostring), (.allowed_actions // "unset") ] | @tsv' 2>/dev/null)"; then
  IFS=$'\t' read -r ACTIONS_ENABLED ALLOWED_ACTIONS <<<"$ap"
  info "Actions 사용: $ACTIONS_ENABLED · 허용 액션: $ALLOWED_ACTIONS"
else
  unk "Actions 설정 조회 실패"
fi
if wp="$(gh api "repos/$ORG/$REPO/actions/permissions/workflow" --jq '
    [ .default_workflow_permissions, ((.can_approve_pull_request_reviews // false) | tostring) ] | @tsv' 2>/dev/null)"; then
  IFS=$'\t' read -r WF_PERM APP_PR <<<"$wp"
  case "$WF_PERM" in
    read)  ok "기본 GITHUB_TOKEN 권한: read" ;;
    write) warn "기본 GITHUB_TOKEN 권한: write — 워크플로 침해 시 저장소 쓰기까지 가능" ;;
    *)     info "기본 GITHUB_TOKEN 권한: $WF_PERM" ;;
  esac
  if [ "$APP_PR" = "true" ]; then
    warn "워크플로가 PR을 승인할 수 있음(can_approve_pull_request_reviews) — 리뷰 게이트 우회 위험"
  else
    ok "워크플로 PR 승인 불가"
  fi
else
  unk "워크플로 토큰 권한 조회 실패"
fi

# ---------------------------------------------------------------------------
# 5. 시크릿 (이름·갱신일만)
# ---------------------------------------------------------------------------
print_secret_list() {
  local label="$1" list="$2" sname supdated
  if [ -z "$list" ]; then
    info "$label: 시크릿 없음"
    return
  fi
  while IFS=$'\t' read -r sname supdated; do
    [ -n "$sname" ] || continue
    if printf '%s' "$sname" | grep -Eqi '(AWS_ACCESS|AWS_SECRET|AZURE|GCP|GOOGLE|DOCKER|KUBECONFIG|SSH_|PRIVATE_KEY|TF_VAR)'; then
      warn "$label: $sname ($supdated) — 장기 클라우드·SSH 키로 보입니다. OIDC 전환을 검토하세요"
    else
      info "$label: $sname ($supdated)"
    fi
  done <<<"$list"
}

head1 "5. 시크릿 (이름·갱신일만, 값은 API로 조회되지 않음)"
if sec="$(gh api "repos/$ORG/$REPO/actions/secrets?per_page=100" --jq '
    .secrets[]? | [ .name, .updated_at ] | @tsv' 2>/dev/null)"; then
  print_secret_list "저장소" "$sec"
else
  unk "저장소 시크릿 조회 실패"
fi
if envsec="$(gh api "repos/$ORG/$REPO/environments?per_page=100" --jq '
    .environments[]?.name' 2>/dev/null)"; then
  while IFS= read -r envname; do
    [ -n "$envname" ] || continue
    if esec="$(gh api "repos/$ORG/$REPO/environments/$envname/secrets?per_page=100" --jq '
        .secrets[]? | [ .name, .updated_at ] | @tsv' 2>/dev/null)"; then
      print_secret_list "환경 $envname" "$esec"
    fi
  done <<<"$envsec"
fi
if orgsec="$(gh api "orgs/$ORG/actions/secrets?per_page=100" --jq '
    .secrets[]? | [ .name, .updated_at ] | @tsv' 2>/dev/null)"; then
  print_secret_list "조직" "$orgsec"
else
  unk "조직 시크릿 조회 불가 (조직 관리자 권한 필요)"
fi

# ---------------------------------------------------------------------------
# 6. 배포 환경 승인 게이트
# ---------------------------------------------------------------------------
head1 "6. 배포 환경 승인 게이트"
if envs="$(gh api "repos/$ORG/$REPO/environments?per_page=100" --jq '
    .environments[]? | [ .name, ((.protection_rules // []) | map(.type) | join(",")) ] | @tsv' 2>/dev/null)"; then
  if [ -z "$envs" ]; then
    info "배포 환경 없음"
  else
    while IFS=$'\t' read -r ENV_NAME ENV_RULES; do
      [ -n "$ENV_NAME" ] || continue
      if printf '%s' "$ENV_RULES" | grep -q required_reviewers; then
        ok "환경 $ENV_NAME: 수동 승인 있음 ($ENV_RULES)"
      elif printf '%s' "$ENV_RULES" | grep -q branch_policy; then
        info "환경 $ENV_NAME: 브랜치 정책만 있음 ($ENV_RULES)"
      else
        warn "환경 $ENV_NAME: 승인 규칙 없음 — 배포가 자동으로 진행됩니다 (${ENV_RULES:-규칙 없음})"
      fi
    done <<<"$envs"
  fi
else
  unk "배포 환경 조회 실패"
fi

# ---------------------------------------------------------------------------
# 7. 배포 키
# ---------------------------------------------------------------------------
head1 "7. 배포 키 (deploy keys)"
if keys="$(gh api "repos/$ORG/$REPO/keys?per_page=100" --jq '
    .[]? | [ .title, ((.read_only // true) | tostring), (.created_at // "-") ] | @tsv' 2>/dev/null)"; then
  if [ -z "$keys" ]; then
    info "배포 키 없음"
  else
    while IFS=$'\t' read -r K_TITLE K_READONLY K_CREATED; do
      [ -n "$K_TITLE" ] || continue
      if [ "$K_READONLY" = "true" ]; then
        info "배포 키 $K_TITLE (읽기 전용, $K_CREATED)"
      else
        warn "배포 키 $K_TITLE (쓰기 가능, $K_CREATED) — 저장소 푸시 경로"
      fi
    done <<<"$keys"
  fi
else
  unk "배포 키 조회 실패"
fi

# ---------------------------------------------------------------------------
# 8. 조직 자격증명: Fine-Grained PAT · SSO
# ---------------------------------------------------------------------------
head1 "8. 조직 자격증명 (Fine-Grained PAT · SSO 승인)"
if pats="$(gh api "orgs/$ORG/personal-access-tokens?per_page=100" --jq '
    .[]? | [ .owner.login, (.repository_selection // "-"), (.token_expires_at // "미표기") ] | @tsv' 2>/dev/null)"; then
  if [ -z "$pats" ]; then
    info "조직에 승인된 fine-grained PAT 없음"
  else
    while IFS=$'\t' read -r P_OWNER P_SCOPE P_EXP; do
      [ -n "$P_OWNER" ] || continue
      if [ "$P_EXP" = "미표기" ]; then
        warn "fine-grained PAT @$P_OWNER: 만료일 없음 (범위 $P_SCOPE)"
      elif [ "$P_SCOPE" = "all" ]; then
        warn "fine-grained PAT @$P_OWNER: 조직 전체 저장소 접근 (만료 $P_EXP)"
      else
        info "fine-grained PAT @$P_OWNER: 선택 저장소 · 만료 $P_EXP"
      fi
    done <<<"$pats"
  fi
else
  unk "fine-grained PAT 목록 조회 불가 (조직 관리자 권한 필요)"
fi
if creds="$(gh api "orgs/$ORG/credential-authorizations?per_page=100" --jq '
    .[]? | [ .login, .credential_type, (.credential_authorized_at // "-") ] | @tsv' 2>/dev/null)"; then
  if [ -z "$creds" ]; then
    info "SSO로 승인된 자격증명 없음"
  else
    while IFS=$'\t' read -r C_LOGIN C_TYPE C_AT; do
      [ -n "$C_LOGIN" ] || continue
      case "$C_TYPE" in
        *"personal access token"*)
          warn "@$C_LOGIN: classic PAT (SSO 승인, $C_AT) — fine-grained 전환 검토" ;;
        *"deploy key"*)
          info "@$C_LOGIN: deploy key ($C_AT)" ;;
        *)
          info "@$C_LOGIN: $C_TYPE ($C_AT)" ;;
      esac
    done <<<"$creds"
  fi
else
  unk "SSO 자격증명 조회 불가 (SAML SSO 조직 관리자 권한 필요)"
fi

# ---------------------------------------------------------------------------
# 9. 워크플로 파일: 정적 키 · OIDC · pull_request_target
# ---------------------------------------------------------------------------
head1 "9. 워크플로 파일 점검 (.github/workflows)"
if wfs="$(gh api "repos/$ORG/$REPO/contents/.github/workflows" --jq '
    .[]? | select(.type == "file") | .path' 2>/dev/null)"; then
  if [ -z "$wfs" ]; then
    info "워크플로 파일 없음"
  else
    WF_N=0
    while IFS= read -r WF; do
      [ -n "$WF" ] || continue
      WF_N=$((WF_N + 1))
      if [ "$WF_N" -gt 40 ]; then
        info "… 워크플로가 40개를 넘어 앞의 40개만 점검했습니다"
        break
      fi
      B64="$(gh api "repos/$ORG/$REPO/contents/$WF" --jq '.content' 2>/dev/null | tr -d '\n' || true)"
      BODY=""
      if [ -n "$B64" ]; then
        BODY="$(printf '%s' "$B64" | base64 -d 2>/dev/null || printf '%s' "$B64" | base64 -D 2>/dev/null || true)"
      fi
      if [ -z "$BODY" ]; then
        info "$WF: 내용 조회 실패 (파일이 크거나 인코딩 확인 필요)"
        continue
      fi
      FLAGS=""
      add_flag() { if [ -z "$FLAGS" ]; then FLAGS="$1"; else FLAGS="$FLAGS · $1"; fi; }
      if printf '%s' "$BODY" | grep -Eq 'id-token:[[:space:]]*write'; then
        add_flag "OIDC"
      fi
      if printf '%s' "$BODY" | grep -q 'pull_request_target'; then
        add_flag "pull_request_target(주의)"
        WARN=$((WARN + 1))
      fi
      if printf '%s' "$BODY" | grep -Eq 'AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AZURE_CREDENTIALS|GOOGLE_APPLICATION_CREDENTIALS|secrets\.(AWS_|GCP_|AZURE_|DOCKER_)'; then
        add_flag "정적키(주의)"
        WARN=$((WARN + 1))
      fi
      if printf '%s' "$BODY" | grep -Eq 'permissions:[[:space:]]*write-all'; then
        add_flag "write-all(주의)"
        WARN=$((WARN + 1))
      fi
      printf '         %s: %s\n' "$WF" "${FLAGS:-특이사항 없음}"
    done <<<"$wfs"
  fi
else
  unk "워크플로 디렉터리를 조회할 수 없습니다 (.github/workflows 없음 또는 권한 부족)"
fi

# ---------------------------------------------------------------------------
# 요약
# ---------------------------------------------------------------------------
head1 "요약"
printf '  주의 항목: %s개 · 권한 부족으로 확인 못한 항목: %s개\n' "$WARN" "$UNK"
printf '  이 스크립트는 읽기 전용입니다. 저장소·조직 설정을 변경하지 않았습니다.\n'
printf '  판정 기준과 적용 시점은 소속 조직의 보안 정책을 따르세요.\n'

if [ "$STRICT" -eq 1 ] && [ "$WARN" -gt 0 ]; then
  exit 1
fi
exit 0
