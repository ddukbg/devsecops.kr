# GitHub Actions OIDC vs 정적 AWS 액세스 키 (기술 시각화 03)

[한국어](README.md) | [English](README_en.md)

레포에 박아둔 `AWS_ACCESS_KEY_ID`는 **평생 열쇠**입니다. 만료가 없고, 회전은 사람이 하고, 유출되면 삭제 전까지 유효하며, 권한은 그 IAM 사용자 정책이 허용하는 전부입니다. OIDC는 키를 두지 않습니다. GitHub Actions가 JWT를 발급하고, AWS STS가 신뢰 정책의 `sub`을 확인한 뒤 **15분~1시간짜리 임시 자격증명**을 줍니다.

이 문서는 릴스 「기술 시각화 03」의 원문 정리입니다. 전환 예시는 [`oidc_workflow_example.yml`](oidc_workflow_example.yml), 최소 권한 신뢰 정책은 [`iam_trust_policy.json`](iam_trust_policy.json)에 있습니다.

## 한눈에

| 항목 | 정적 액세스 키 | GitHub OIDC |
| --- | --- | --- |
| 수명 | 무기한 (`AKIA...`, 비활성화 전까지 유효) | **15분 ~ 1시간** (STS 임시 자격증명, `ASIA...`) |
| 유출 시 | 삭제 전까지 사용 가능 — 사후 대응뿐 | 만료되면 끝 — 재사용 불가 |
| 회전 | 사람이 직접 | 매 실행 자동 |
| 권한 | IAM 사용자 정책 전부 | **레포·브랜치·environment 단위** 역할 |
| 저장 위치 | 코드·`~/.aws/credentials`·GitHub Secrets·CI 캐시 | **저장하지 않음** (실행 중 메모리) |
| 감사 | `userIdentity.type = IAMUser` (누가 썼는지 흐림) | `AssumedRole` + 세션 이름(실행 단위 추적) |
| 필요한 설정 | IAM 사용자 + 키 발급 | OIDC 공급자 1회 + 역할 + 워크플로 `id-token: write` |

## 1. 정적 키는 어디까지 가는가

```
개발자 노트북 (~/.aws/credentials, .env)
   └─ GitHub Secrets (레포·조직·워크플로)
        └─ CI 러너 (로그·아티팩트·캐시에 남는다)
             └─ IAM User  AKIA...  만료 없음 · 회수 전까지 유효
```

키가 코드에 한 번 들어가면 **git history·포크·아티팩트 어디에도 남습니다.** `git rm`으로 파일을 지워도 커밋 기록에는 남고, 포크된 저장소에는 그대로 복제됩니다. 키를 지우는 일은 결국 **사람이 기억해서** 해야 합니다.

## 2. 유출 이후의 전형적 흐름

릴스의 타임라인은 실측 시간이 아니라 **순서**입니다.

| 시점 | 일어나는 일 | 관찰 지점 |
| --- | --- | --- |
| 커밋 직후 | 공개 레포에 키가 포함된 push, 자동 스캐너가 수집 | GitHub secret scanning, 외부 크롤러 |
| 수십 초 | `aws sts get-caller-identity` — 계정 ID·권한 확인 | CloudTrail (`GetCallerIdentity`는 흔히 기록됨) |
| 분 단위 | `s3 ls`, `ec2 describe-*` — 자원 목록·데이터 접근 | CloudTrail 데이터 이벤트(별도 활성화 필요) |
| 그날 안에 | `run-instances`, 비용 발생, 자원 삭제 | Billing·Config·GuardDuty |

**핵심**: `GetCallerIdentity` 한 줄이면 계정 주인이 바뀝니다. 그리고 삭제 전에 이미 벌어진 일은 되돌릴 수 없습니다. 사후 대응(키 삭제 → CloudTrail 조사 → 권한 회수)은 **피해를 줄이는 절차가 아니라, 남은 피해를 멈추는 절차**입니다.

> 같은 문제의식의 실제 사례: 이 저장소의 [`1password-github-breach`](../1password-github-breach/README.md)는 직원 GitHub 계정 침해가 CI/CD와 백엔드로 이어진 공급망 사고를 다룹니다. 자격증명이 사람 계정과 저장소에 흩어져 있을 때의 위험은 같습니다.

## 3. OIDC 흐름

```
GitHub Actions (permissions: id-token: write)
   └─ GitHub OIDC 공급자 → 서명된 JWT 발급 (iss/sub/aud)
        └─ AWS STS AssumeRoleWithWebIdentity
             └─ 신뢰 정책의 StringEquals(sub, aud) 확인
                  └─ 임시 자격증명 (15분 ~ 1시간)
```

| JWT 클레임 | 값(예) | 신뢰 정책에서 쓰는 방법 |
| --- | --- | --- |
| `iss` | `https://token.actions.githubusercontent.com` | OIDC 공급자 ARN으로 고정 |
| `sub` | `repo:my-org/my-repo:ref:refs/heads/main` | `StringEquals` — **저장소·브랜치·environment 지정** |
| `aud` | `sts.amazonaws.com` (AWS용 기본 audience) | `StringEquals` — **반드시 함께 건다** |

JWT 수명은 GitHub 문서에 숫자로 명시돼 있지 않지만, GitHub이 배포한 예시 토큰의 `exp - iat`는 **300초(5분)** 입니다. 그래서 릴스에서도 "5분"으로 표기했습니다. 실제 방어선은 JWT가 아니라 **STS가 주는 임시 자격증명의 수명**이며, 이는 역할의 `MaxSessionDuration`(기본 1시간, 최소 15분)과 워크플로의 `role-duration-seconds`로 정해집니다.

### sub 형식

| 트리거 | sub |
| --- | --- |
| 브랜치 push | `repo:ORG/REPO:ref:refs/heads/main` |
| 태그 push | `repo:ORG/REPO:ref:refs/tags/v1.2.3` |
| environment 사용 | `repo:ORG/REPO:environment:production` |
| PR | `repo:ORG/REPO:pull_request` |
| 재사용 워크플로 | `repo:ORG/REPO:...:job_workflow_ref:ORG/REPO/.github/workflows/x.yml@refs/heads/main` |

> **sub 문자열은 반드시 실제 토큰을 디코드해서 확인하세요.** 저장소 이전·이름 변경, 조직의 subject claim 커스터마이즈 설정, GitHub Enterprise Server 사용 여부에 따라 값이 달라집니다. 문서 예시를 그대로 복사해 넣고 "왜 안 되지" 하는 경우가 가장 흔합니다.

## 4. 신뢰 정책

[`iam_trust_policy.json`](iam_trust_policy.json)의 핵심은 두 줄입니다.

```json
"StringEquals": {
  "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
  "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:ref:refs/heads/main"
}
```

| 하지 말아야 할 것 | 이유 |
| --- | --- |
| `"StringLike": {"...:sub": "repo:my-org/*"}` | 조직의 **모든 저장소**가 이 역할을 쓸 수 있다 |
| `"StringLike": {"...:sub": "*"}` | GitHub의 **모든 저장소**가 이 역할을 쓸 수 있다 (실제 사고 사례가 있는 형태) |
| `aud` 조건 누락 | 다른 서비스용으로 발급된 토큰이 통과할 여지가 생긴다 |
| `sub`에 `ref:refs/heads/*` | 아무 브랜치(포크 PR 브랜치 포함)나 배포 가능 |
| 역할에 `AdministratorAccess` | 자격증명 수명이 짧아도 권한이 크면 피해는 그대로다 |

권장 형태:

| 목적 | 조건 |
| --- | --- |
| main 배포 | `StringEquals` sub = `repo:ORG/REPO:ref:refs/heads/main` |
| 운영 environment | `StringEquals` sub = `repo:ORG/REPO:environment:production` |
| 여러 브랜치 빌드(읽기 전용) | `StringLike` sub = `repo:ORG/REPO:ref:refs/heads/*` + **읽기 전용 정책** |
| PR 검증 | `StringLike` sub = `repo:ORG/REPO:pull_request` — **`pull_request_target`과 혼동 금지** |

## 5. 전환 5단계 — 키를 지우는 순서가 중요하다

1. **OIDC 공급자 등록** (계정당 1회)
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com
   ```
2. **역할 생성 + 신뢰 정책 교체** — [`iam_trust_policy.json`](iam_trust_policy.json)에서 계정 ID·조직·저장소·브랜치를 실제 값으로 바꿔 적용하고, 권한 정책은 필요한 액션만 남깁니다.
3. **워크플로 수정** — [`oidc_workflow_example.yml`](oidc_workflow_example.yml)처럼 `permissions: id-token: write`를 추가하고 `configure-aws-credentials`로 역할을 받습니다.
4. **검증** — `aws sts get-caller-identity`가 `AssumedRole`로 나오고, 배포가 정상 동작하는지 확인합니다. **이 단계까지 키를 지우지 않습니다.**
5. **키 폐기** — Secrets에서 삭제 → `aws iam update-access-key --status Inactive` → 며칠 관찰 → `delete-access-key`. 그리고 **CloudTrail에서 폐기 이후 그 키로 온 요청이 없는지** 확인합니다.

> 4번과 5번 사이를 건너뛰면 롤백 수단 없이 장애를 만납니다. 또한 키를 비활성화한 뒤에도 **다른 저장소·다른 팀의 사본**이 남아 있을 수 있으니, 조직 전체에서 같은 키를 쓰고 있지 않은지 먼저 확인하세요.

## 6. 흔한 함정

| 함정 | 증상 | 대응 |
| --- | --- | --- |
| `id-token: write` 누락 | `Credentials could not be loaded` / 토큰 요청 실패 | 워크플로 또는 job 레벨에 추가 |
| job 레벨 `permissions`가 워크플로 값을 덮어씀 | 워크플로에 썼는데도 실패 | job 블록의 `permissions` 확인 |
| `pull_request` 이벤트에서 배포 시도 | `sub`가 `:pull_request`로 와서 불일치 | 배포는 `push`·`workflow_dispatch`로만 |
| `pull_request_target`에 `id-token: write` | 포크 코드가 신뢰 정책을 통과할 수 있음 | **금지**. 필요하면 별도 역할·검토 게이트 |
| 신뢰 정책에 `StringLike` 와일드카드 | 의도보다 넓은 저장소가 통과 | `StringEquals` 로 좁히기 |
| `audience` 불일치 | `Not authorized to perform sts:AssumeRoleWithWebIdentity` | 워크플로 `audience`와 정책 `aud` 일치 |
| 세션 길이 초과 | `DurationSeconds exceeds MaxSessionDuration` | 역할의 `MaxSessionDuration` 확인 |
| 저장소 이전·이름 변경 | 갑자기 인증 실패 | 새 `sub`로 정책 갱신 |
| Secrets에 키가 남음 | 전환 후에도 유출면 존재 | 5단계 폐기 절차까지 수행 |
| 서드파티 액션 태그 사용 | 태그 이동으로 악성 코드 실행 가능 | 커밋 SHA로 고정 |

## 7. 점검 (읽기 전용)

```bash
# 1) OIDC 공급자가 등록되어 있는가
aws iam list-open-id-connect-providers

# 2) 역할의 신뢰 정책에 sub/aud 조건이 있는가 (조건이 없으면 그대로 출력된다)
aws iam get-role --role-name gh-actions-deploy \
  --query 'Role.AssumeRolePolicyDocument' --output json

# 3) 정적 키가 아직 살아 있는가
aws iam list-users --query 'Users[].UserName' --output text
aws iam list-access-keys --user-name ci-bot \
  --query 'AccessKeyMetadata[].{id:AccessKeyId,status:Status,created:CreateDate}' --output table

# 4) 키가 마지막으로 언제 쓰였는가 (90일 이상 미사용 = 후보)
aws iam get-access-key-last-used --access-key-id AKIA...

# 5) 폐기 이후 그 키로 온 요청이 있는가
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetCallerIdentity \
  --start-time 2026-11-20 --max-items 50
```

체크리스트:

- [ ] 워크플로 Secrets에 `AWS_ACCESS_KEY_ID`·`AWS_SECRET_ACCESS_KEY`가 남아 있지 않다
- [ ] 신뢰 정책의 `sub`이 **저장소+브랜치 또는 environment**까지 지정한다
- [ ] `aud` 조건이 `sts.amazonaws.com`으로 고정돼 있다
- [ ] 역할 권한이 배포에 필요한 최소 액션이다
- [ ] `pull_request_target` 워크플로에 `id-token: write`가 없다
- [ ] 서드파티 액션이 SHA로 고정돼 있다
- [ ] CloudTrail에 `IAMUser` 자격증명 사용이 남아 있지 않다

## 8. 이 폴더의 파일

| 파일 | 내용 |
| --- | --- |
| [`oidc_workflow_example.yml`](oidc_workflow_example.yml) | `permissions: id-token: write` + `aws-actions/configure-aws-credentials@v4` 예시. 세션 이름에 `run_id`를 넣어 CloudTrail에서 실행 단위 추적 |
| [`iam_trust_policy.json`](iam_trust_policy.json) | `StringEquals`로 `sub`(main 브랜치)·`aud`(sts.amazonaws.com)를 고정한 최소 신뢰 정책 |

두 파일의 계정 ID·조직·저장소·역할 이름은 **예시값**입니다. 그대로 적용하면 동작하지 않습니다.

## 9. 2분 요약

- 정적 키는 **만료가 없고 회전이 수동**이며, 유출되면 삭제 전까지 유효합니다.
- OIDC는 키를 저장하지 않고, **매 실행 JWT → STS → 15분~1시간 자격증명**을 받습니다.
- 방어의 핵심은 키를 없애는 것 + **신뢰 정책을 좁히는 것**(`StringEquals` sub·aud, 역할 최소 권한).
- 전환은 **키를 지우기 전에 OIDC로 먼저 성공시키고**, 폐기는 비활성화 → 관찰 → 삭제 순서로.
- 오늘 할 일: 워크플로 Secrets에 `AKIA`가 있는지, 있다면 신뢰 정책의 `sub`이 저장소·브랜치까지 지정돼 있는지.

## 출처

- GitHub Docs — About security hardening with OpenID Connect: https://docs.github.com/en/actions/concepts/security/openid-connect
- GitHub Docs — Configuring OpenID Connect in Amazon Web Services: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
- GitHub Docs — OIDC subject claim reference (`sub` 형식): https://docs.github.com/en/actions/reference/security/oidc
- AWS — Creating a role for web identity or OIDC: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html
- AWS — `AssumeRoleWithWebIdentity`: https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html
- aws-actions/configure-aws-credentials: https://github.com/aws-actions/configure-aws-credentials

확인 기준일: 2026-11-27. JWT 클레임·`sub` 형식·액션 입력값은 GitHub 변경으로 달라질 수 있습니다. 적용 전에 공식 문서와 실제 발급된 토큰을 함께 확인하세요.
