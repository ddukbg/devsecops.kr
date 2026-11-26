# 1Password 직원 GitHub 계정 침해로 본 CI/CD · 개발자 계정 공급망 방어

[한국어](README.md) | [English](README_en.md)

2026년 11월 25일, 1Password가 백엔드 침해를 공개했습니다. 직원의 **기업 GitHub 계정 하나**가 탈취되어 비공개 소스코드 복사, **CI/CD 접근**, 백엔드 서비스에 대한 **악성코드 푸시**, 그리고 그 결과로 일부 고객의 계정 메타데이터 다운로드까지 이어졌습니다. 고객 볼트는 Zero-Knowledge 구조 덕에 비노출이었지만, 사고 경로 자체는 어떤 조직에나 그대로 재현됩니다.

> 단일 개발자 계정 → 소스코드 → CI/CD → 프로덕션 백엔드.
> 이 사슬에서 **사람 계정과 배포 권한 사이에 게이트가 없으면** 비밀번호 관리자가 아니라도 똑같이 뚫립니다.

## 한눈에

| 항목 | 확인된 내용 |
| --- | --- |
| 탐지 | 2026-11-19, 직원 기업 GitHub 계정 무단 접근 징후로 조사 시작 |
| 공개 | 2026-11-25 (1Password 공식 블로그) |
| 침입 경로 | 직원 기업 GitHub 계정 탈취 → 비공개 저장소 소스코드 복사 · CI/CD 시스템 접근 · 백엔드 서비스에 악성코드 푸시 → 고객 행정 데이터 다운로드 |
| 유출 데이터 | 이름·이메일, 계정/사용자 식별자, 계정 생성·최근 로그인 시각, 공개키, SRP 파라미터, 초대·프로비저닝·복구 메일 토큰, 비밀이 아닌 내부 메타데이터(버전·파일 숫자 ID 등) |
| 비노출 | 고객 볼트 내용·항목, 볼트 보호 키, 계정 복구 키, 1Password 앱·브라우저 확장프로그램 |
| 규모 | "일부(subset) 고객"만 언급, **정확한 수는 미공개** |

## 1. 사건 개요

- 1Password는 **2026-11-19**에 직원의 기업 GitHub 계정이 침해된 징후를 포착하고 조사에 들어갔습니다.
- 공격자는 그 계정으로 **비공개 저장소의 소스코드에 접근**하고, **백엔드 서비스에 악성코드를 푸시**했습니다. 푸시된 코드는 고객 행정 데이터를 **다운로드**하는 동작을 했습니다.
- 같은 계정으로 **CI/CD 시스템에도 접근**했습니다. 1Password는 CI/CD에 제품 운영용 인프라 시크릿이 존재한다고 밝혔고, 노출 가능성이 있는 자격증명을 **전면 로테이션**했습니다.
- 고객 볼트·항목·볼트 보호 키·복구 키는 Zero-Knowledge 구조상 공격자에게 노출되지 않았습니다. 1Password는 계정 비밀번호와 Secret Key를 저장하지 않습니다.

## 2. 노출된 것과 안전한 것

| 구분 | 항목 | 실무 의미 |
| --- | --- | --- |
| **노출** | 이름, 로그인 이메일 | 1Password 사용자 명단 → **표적 피싱**의 재료 |
| **노출** | 계정·사용자 식별자, 계정 생성·최근 로그인 시각 | 계정 존재 여부·활동 패턴 추정 |
| **노출** | 공개키, SRP 프로토콜 파라미터 | 설계상 공개 정보. 계정 접근에 사용 불가 |
| **노출** | 초대·프로비저닝·복구 메일 링크의 토큰 | 단독으로는 계정 접근 불가. **SSO 로그인 또는 등록 이메일로 발송된 코드**가 함께 필요 |
| **노출** | 비밀이 아닌 내부 메타데이터(버전·파일 숫자 ID) | 내부 구조 추정용 |
| **안전** | 볼트 내용·항목, 볼트 보호 키 | 공격자 서버에 도달한 데이터 아님 |
| **안전** | 계정 복구 키, 앱·브라우저 확장 | 영향 없음 |
| **노출(회사 자산)** | 비공개 소스코드, CI/CD 인프라 시크릿 | 고객 데이터는 아니지만 **인프라 자격증명**이 포함 |

> 핵심은 마지막 줄입니다. 고객 볼트가 안전했던 이유는 암호화 구조이고, 사고가 멈춘 지점은 **자격증명 로테이션**입니다. 구조가 같지 않은 조직은 같은 공격에서 다른 결과를 얻습니다.

## 3. 1Password 대응

- 침해된 GitHub 계정 **비활성화**, 탈취된 토큰 **폐기**, 공격자가 만든 접근 **제거**
- 노출 가능성이 있는 **내부 자격증명 전체 로테이션·폐기**
- 영향 서비스의 **정상 버전 복원**
- 초대·복구 메일 인증코드를 **6자리 숫자 → 10자리 영숫자**로 상향 (무차별 대입 사실상 불가)
- 내부 GitHub · CI/CD · 엔드포인트 통제 강화 및 탐지 룰 추가
- 외부 보안 전문가를 투입해 격리·복구 검증, **프로비저닝 토큰을 이용한 계정 탈취 흔적은 없다고 확인**
- 고객 조치 요구 없음. 단, **초대·계정 복구를 사칭하는 피싱** 주의 공지

## 4. 2026-11-26 기준 아직 확인되지 않은 것

- **직원 계정이 어떻게 탈취됐는지** (악성코드 감염·세션 토큰 탈취·피싱 등 초기 침입 벡터) — 공식 공지에 없음
- **백엔드 배포 게이트 통과 여부** — 악성코드 푸시가 PR 리뷰·브랜치 보호·배포 승인을 거쳤는지, 아니면 우회했는지 미공개
- **영향 고객 수** — "일부(subset)"만 표기
- **공격자 귀속** — 미확인
- 토큰 유효기간(TTL)·재사용 제한 등 초대/복구 링크의 세부 정책

이 항목들은 공지가 갱신되면 바뀔 수 있습니다. 사내 보고서에 인용할 때는 "미공개"로 남겨 두는 편이 안전합니다.

## 5. 실무자 관점: 어디를 먼저 막을까

1. **사람 계정 = 배포 권한**이 되지 않게 분리합니다. 개인 GitHub 계정으로 프로덕션 배포가 가능한 구조라면, 그 계정 하나가 곧 프로덕션 권한입니다.
2. **강제 푸시(force-push) 금지**를 배포 브랜치에 겁니다. 오픈소스 저장소를 노린 `PolinRider` 류 캠페인은 PR에 강제 푸시로 로더를 심는 방식을 씁니다.
3. **CI/CD의 장기 키를 없앱니다.** 저장소 시크릿에 클라우드 액세스 키가 남아 있으면, 저장소 쓰기 권한 하나가 클라우드 권한 전체가 됩니다.

## 6. DevSecOps 4대 통제

### ① Classic PAT 금지 · Fine-Grained PAT + Org SSO/패스키 강제

- 조직 정책에서 **classic PAT 발급을 차단**하고, fine-grained PAT는 **승인제·만료일 필수**로 운영합니다.
- 조직 멤버는 **SAML SSO 또는 패스키**로 인증하고, 2FA를 조직 차원에서 강제합니다.
- 남아 있는 자격증명은 주기적으로 조회합니다(조직 관리자 권한 필요).

```bash
# 조직에 승인된 fine-grained PAT (소유자·저장소 범위·만료)
gh api "orgs/ORG/personal-access-tokens?per_page=100" \
  --jq '.[] | [.owner.login, .repository_selection, (.token_expires_at // "미표기")] | @tsv'

# SSO로 승인된 자격증명 (classic PAT·SSH 키·배포 키)
gh api "orgs/ORG/credential-authorizations?per_page=100" \
  --jq '.[] | [.login, .credential_type, (.credential_authorized_at // "-")] | @tsv'
```

### ② `main`·배포 브랜치 직접 푸시 금지 + 2인 CODEOWNERS 승인 + 커밋 서명

- 배포 브랜치에 **직접 푸시·강제 푸시·브랜치 삭제를 금지**합니다.
- **최소 2인 승인**과 **CODEOWNERS 리뷰 필수**를 함께 겁니다. 1인 승인은 계정 하나만 뚫려도 무력화됩니다.
- **커밋 서명(verified commit)** 을 요구해, 탈취된 계정으로 만든 커밋이 히스토리에 섞이지 않게 합니다.
- 관리자에게도 규칙을 적용(`enforce_admins`)합니다. 예외는 사고 때 가장 먼저 악용됩니다.

```bash
# 기본 브랜치 보호 상태 확인
gh api repos/ORG/REPO/branches/main/protection \
  --jq '{approvals: .required_pull_request_reviews.required_approving_review_count,
         codeowners: .required_pull_request_reviews.require_code_owner_reviews,
         signatures: .required_signatures.enabled,
         enforce_admins: .enforce_admins.enabled,
         force_push: .allow_force_pushes.enabled}'
```

### ③ CI/CD 정적 키 제거 → OIDC 단기 자격증명 + Production Environment 수동 승인

- 클라우드 자격증명은 **저장소 시크릿의 장기 키 대신 OIDC 단기 토큰**으로 받습니다(AWS `AssumeRoleWithWebIdentity`, GCP Workload Identity Federation, Azure federated credential).
- 워크플로 기본 토큰은 **읽기 전용**으로 두고, 필요한 잡에서만 최소 권한을 올립니다.

```yaml
permissions:
  contents: read
  id-token: write   # OIDC 단기 자격증명용
```

- 프로덕션 배포는 **GitHub Environment의 필수 리뷰어(수동 승인)** 를 통과하게 합니다. CI가 뚫려도 마지막에 사람이 서는 구조입니다.
- 시크릿은 **이름과 갱신일**만 주기적으로 확인합니다. 값은 API로 조회되지 않습니다.

```bash
gh api "repos/ORG/REPO/actions/secrets?per_page=100" --jq '.secrets[] | [.name, .updated_at] | @tsv'
gh api "repos/ORG/REPO/environments" \
  --jq '.environments[] | [.name, ((.protection_rules // []) | map(.type) | join(","))] | @tsv'
```

### ④ 초대·복구 토큰 짧은 TTL + 10자리 이상 코드 + 피싱 대응 공지

- 초대·프로비저닝·복구 링크의 토큰은 **1회용·짧은 TTL(예: 15~60분)** 로 발급하고, 검증 엔드포인트에 **시도 횟수 제한**을 겁니다.
- 코드는 추측 불가능한 길이로 발급합니다. 1Password가 6자리 숫자 → **10자리 영숫자**로 올린 이유가 여기 있습니다.
- 토큰 + 코드 + SSO처럼 **요소를 2개 이상** 요구하고, 초대·복구가 발생하면 계정 소유자에게 **알림**을 보냅니다.
- 사고 공지에는 "우리는 비밀번호·Secret Key를 절대 묻지 않는다"와 **신고 채널**을 명시합니다.

## 7. 이 저장소의 점검 스크립트

`audit_github_cicd.sh` 는 위 ①~③ 항목을 `gh` CLI로 **읽기만** 합니다. 쓰기 API는 호출하지 않습니다.

```bash
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/1password-github-breach/audit_github_cicd.sh
bash audit_github_cicd.sh ORG/REPO
bash audit_github_cicd.sh ORG/REPO --branch main --branch release
```

- 점검: 저장소 기본 정보 → 기본 브랜치 보호(승인 수·CODEOWNERS·커밋 서명·강제 푸시) → rulesets → Actions 토큰 권한 → 시크릿 이름·갱신일 → 배포 환경 승인 → 배포 키 → 조직 fine-grained PAT·SSO 자격증명 → 워크플로 파일의 정적 키·OIDC·`pull_request_target` 사용
- 조직 단위 조회는 **조직 관리자 권한**이 있어야 하며, 권한이 없으면 `[미확인]` 으로 표시하고 계속 진행합니다.
- 판정 결과를 바꾸지 않습니다. 스크립트는 조회만 하고, 적용은 조직 정책에 따라 직접 합니다.

## 8. 1Password 사용 팀·개인 체크

- **비밀번호·Secret Key 변경은 필요 없습니다**(1Password 공식). 볼트와 키는 노출되지 않았습니다.
- **초대·계정 복구를 사칭하는 메일**을 조심합니다. 링크를 누르지 말고, 1Password 앱이나 직접 입력한 공식 주소로 들어가 확인합니다.
- 1Password는 **비밀번호·Secret Key·인증코드를 요구하지 않습니다**. 요구하는 연락은 전부 사칭입니다.
- 의심 메일·문자는 `support@1password.com` 으로 신고합니다.
- 사내에서 1Password를 SSO로 운영한다면, 침해 계정과 연결된 IdP 세션·프로비저닝(SCIM) 토큰도 함께 점검합니다.

## 출처

- 1Password 공식 — Update on a security incident involving 1Password's backend systems (2026-11-25): https://1password.com/blog/update-on-nov-2026-security-incident
- BleepingComputer — 1Password customer data stolen after employee GitHub account breach (2026-11-25): https://www.bleepingcomputer.com/news/security/1password-customer-data-stolen-after-employee-github-account-breach/
- The Hacker News — 1Password Hacked, Customer Data and Source Code Stolen in GitHub Account Breach (2026-11-26): https://thehackernews.com/2026/11/1password-hacked-customer-data-and.html

확인 기준일: 2026-11-26. 사건 수사·공지가 갱신되면 유출 범위와 영향 규모가 바뀔 수 있으므로 벤더 공지를 함께 확인하세요.
