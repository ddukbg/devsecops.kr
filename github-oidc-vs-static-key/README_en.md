# GitHub Actions OIDC vs static AWS access keys (Tech Visual 03)

[한국어](README.md) | [English](README_en.md)

An `AWS_ACCESS_KEY_ID` committed to a repo is a **key for life**. It never expires, rotation is manual, a leak stays valid until someone deletes it, and its permissions are whatever the IAM user policy allows. OIDC keeps no key. GitHub Actions issues a JWT, AWS STS checks the `sub` in the trust policy, and returns **temporary credentials lasting 15 minutes to 1 hour**.

This is the write-up behind the Reel "Tech Visual 03". The migration example is [`oidc_workflow_example.yml`](oidc_workflow_example.yml); the least-privilege trust policy is [`iam_trust_policy.json`](iam_trust_policy.json).

## At a glance

| Item | Static access key | GitHub OIDC |
| --- | --- | --- |
| Lifetime | indefinite (`AKIA...`, valid until deactivated) | **15 min – 1 hour** (STS credentials, `ASIA...`) |
| On leak | usable until deleted — only after-the-fact response | expires — cannot be reused |
| Rotation | manual | automatic on every run |
| Permissions | everything the IAM user policy allows | role scoped to **repo · branch · environment** |
| Stored in | code, `~/.aws/credentials`, GitHub Secrets, CI caches | **nowhere** (memory during the run) |
| Audit trail | `userIdentity.type = IAMUser` (unclear who) | `AssumedRole` + session name (per-run) |
| Setup | IAM user + key | one-time OIDC provider + role + `id-token: write` |

## 1. How far a static key travels

```
developer laptop (~/.aws/credentials, .env)
   └─ GitHub Secrets (repo · org · workflow)
        └─ CI runner (logs · artifacts · caches)
             └─ IAM User  AKIA...  no expiry · valid until revoked
```

Once a key lands in code it stays in **git history, forks and artifacts**. `git rm` removes the file, not the commit, and forks keep their copy. Deleting the key depends on **a person remembering to do it**.

## 2. The typical post-leak sequence

The Reel timeline shows **order**, not measured latency.

| When | What happens | Where to look |
| --- | --- | --- |
| right after commit | key pushed to a public repo, automated scanners collect it | GitHub secret scanning, external crawlers |
| seconds | `aws sts get-caller-identity` — confirm account and permissions | CloudTrail (this call is usually recorded) |
| minutes | `s3 ls`, `ec2 describe-*` — enumerate resources and data | CloudTrail data events (must be enabled) |
| same day | `run-instances`, spend, resource deletion | Billing · Config · GuardDuty |

**The point**: one `get-caller-identity` changes who owns the account. And what already happened before deletion cannot be undone. Post-incident work (delete key → investigate CloudTrail → revoke) is not damage repair — it **stops further damage**.

> A real case in this repo: [`1password-github-breach`](../1password-github-breach/README_en.md) covers an employee GitHub account compromise that reached CI/CD and backend systems. The risk is the same when credentials are scattered across people and repositories.

## 3. The OIDC flow

```
GitHub Actions (permissions: id-token: write)
   └─ GitHub OIDC provider → signed JWT (iss/sub/aud)
        └─ AWS STS AssumeRoleWithWebIdentity
             └─ trust policy checks StringEquals(sub, aud)
                  └─ temporary credentials (15 min – 1 hour)
```

| JWT claim | Value (example) | How the trust policy uses it |
| --- | --- | --- |
| `iss` | `https://token.actions.githubusercontent.com` | pinned by the OIDC provider ARN |
| `sub` | `repo:my-org/my-repo:ref:refs/heads/main` | `StringEquals` — **pin repo, branch, environment** |
| `aud` | `sts.amazonaws.com` (default audience for AWS) | `StringEquals` — **always include it** |

GitHub does not state a numeric JWT lifetime in its docs, but GitHub's own example token has `exp - iat` of **300 seconds (5 minutes)**, which is why the Reel says five minutes. The real control is not the JWT but the **STS credential lifetime**, set by the role's `MaxSessionDuration` (default 1 hour, minimum 15 minutes) and the workflow's `role-duration-seconds`.

### `sub` formats

| Trigger | `sub` |
| --- | --- |
| branch push | `repo:ORG/REPO:ref:refs/heads/main` |
| tag push | `repo:ORG/REPO:ref:refs/tags/v1.2.3` |
| with environment | `repo:ORG/REPO:environment:production` |
| pull request | `repo:ORG/REPO:pull_request` |
| reusable workflow | `repo:ORG/REPO:...:job_workflow_ref:ORG/REPO/.github/workflows/x.yml@refs/heads/main` |

> **Decode a real token before writing the condition.** Repository transfers and renames, an organization's custom subject claims, and GitHub Enterprise Server all change the string. Copying the documentation example verbatim and then wondering why it fails is the most common mistake.

## 4. The trust policy

The core of [`iam_trust_policy.json`](iam_trust_policy.json) is two lines.

```json
"StringEquals": {
  "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
  "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:ref:refs/heads/main"
}
```

| Do not do this | Why |
| --- | --- |
| `"StringLike": {"...:sub": "repo:my-org/*"}` | **every repo in the org** can assume the role |
| `"StringLike": {"...:sub": "*"}` | **every repo on GitHub** can assume it (a pattern seen in real incidents) |
| omit the `aud` condition | tokens issued for another service may pass |
| `ref:refs/heads/*` in `sub` | any branch — including fork PR branches — can deploy |
| `AdministratorAccess` on the role | short lifetime does not help when the blast radius is huge |

Recommended shapes:

| Purpose | Condition |
| --- | --- |
| deploy from main | `StringEquals` sub = `repo:ORG/REPO:ref:refs/heads/main` |
| production environment | `StringEquals` sub = `repo:ORG/REPO:environment:production` |
| build all branches (read-only) | `StringLike` sub = `repo:ORG/REPO:ref:refs/heads/*` + **read-only policy** |
| PR validation | `StringLike` sub = `repo:ORG/REPO:pull_request` — **never confuse with `pull_request_target`** |

## 5. Migration in five steps — order matters

1. **Register the OIDC provider** (once per account)
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com
   ```
2. **Create the role and replace its trust policy** with real account/org/repo/branch values from [`iam_trust_policy.json`](iam_trust_policy.json); trim the permission policy to the actions you deploy.
3. **Update the workflow** — add `permissions: id-token: write` and assume the role as in [`oidc_workflow_example.yml`](oidc_workflow_example.yml).
4. **Verify** — `aws sts get-caller-identity` shows `AssumedRole` and deploys work. **Do not delete the key yet.**
5. **Retire the key** — remove it from Secrets → `aws iam update-access-key --status Inactive` → observe for a few days → `delete-access-key`. Then confirm in CloudTrail that **no requests came from that key after retirement**.

> Skipping between steps 4 and 5 leaves you with no rollback path. Also check whether other repositories or teams share the same key before deactivating it.

## 6. Common pitfalls

| Pitfall | Symptom | Fix |
| --- | --- | --- |
| missing `id-token: write` | `Credentials could not be loaded` / token request fails | add at workflow or job level |
| job-level `permissions` overrides the workflow | set at workflow yet still fails | check the job block |
| deploying on `pull_request` | `sub` is `:pull_request`, condition mismatch | deploy only on `push` / `workflow_dispatch` |
| `id-token: write` on `pull_request_target` | fork code can satisfy the trust policy | **forbid**; use a separate role plus a review gate |
| `StringLike` wildcards | more repos pass than intended | tighten with `StringEquals` |
| `audience` mismatch | `Not authorized to perform sts:AssumeRoleWithWebIdentity` | match workflow `audience` and policy `aud` |
| session longer than allowed | `DurationSeconds exceeds MaxSessionDuration` | check the role |
| repo renamed or transferred | sudden auth failure | update `sub` |
| key still present in Secrets | exposure surface remains | finish step 5 |
| third-party actions on tags | tag move enables malicious code | pin to commit SHA |

## 7. Read-only checks

```bash
# 1) is an OIDC provider registered?
aws iam list-open-id-connect-providers

# 2) does the role's trust policy constrain sub/aud? (no condition = printed as is)
aws iam get-role --role-name gh-actions-deploy \
  --query 'Role.AssumeRolePolicyDocument' --output json

# 3) are static keys still active?
aws iam list-users --query 'Users[].UserName' --output text
aws iam list-access-keys --user-name ci-bot \
  --query 'AccessKeyMetadata[].{id:AccessKeyId,status:Status,created:CreateDate}' --output table

# 4) when was a key last used? (90+ days = candidate for removal)
aws iam get-access-key-last-used --access-key-id AKIA...

# 5) any requests from that key after retirement?
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetCallerIdentity \
  --start-time 2026-11-20 --max-items 50
```

Checklist:

- [ ] no `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` left in workflow Secrets
- [ ] trust policy `sub` names **repo + branch or environment**
- [ ] `aud` pinned to `sts.amazonaws.com`
- [ ] role policy is the minimum set of actions
- [ ] no `id-token: write` on `pull_request_target` workflows
- [ ] third-party actions pinned to SHAs
- [ ] CloudTrail shows no `IAMUser` credential use

## 8. Files here

| File | Contents |
| --- | --- |
| [`oidc_workflow_example.yml`](oidc_workflow_example.yml) | `permissions: id-token: write` + `aws-actions/configure-aws-credentials@v4`, with `run_id` in the session name so CloudTrail distinguishes runs |
| [`iam_trust_policy.json`](iam_trust_policy.json) | minimal trust policy with `StringEquals` on `sub` (main branch) and `aud` (sts.amazonaws.com) |

Account ID, org, repo and role names are **placeholders**; copying them verbatim will not work.

## 9. Two-minute summary

- Static keys **never expire, rotate manually**, and stay valid after a leak until deleted.
- OIDC stores nothing: **JWT per run → STS → 15 min–1 hour credentials**.
- Defence is removing the key **and narrowing the trust policy** (`StringEquals` on sub and aud, least-privilege role).
- Migrate so OIDC **works before you delete the key**; retire by deactivating → observing → deleting.
- Today: check workflow Secrets for `AKIA`, and if present, whether `sub` names the repo and branch.

## Sources

- GitHub Docs — About security hardening with OpenID Connect: https://docs.github.com/en/actions/concepts/security/openid-connect
- GitHub Docs — Configuring OpenID Connect in Amazon Web Services: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
- GitHub Docs — OIDC subject claim reference (`sub` formats): https://docs.github.com/en/actions/reference/security/oidc
- AWS — Creating a role for web identity or OIDC: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html
- AWS — `AssumeRoleWithWebIdentity`: https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html
- aws-actions/configure-aws-credentials: https://github.com/aws-actions/configure-aws-credentials

Checked on 2026-11-27. Claims, `sub` formats and action inputs can change; verify against the official docs and a real decoded token before applying.
