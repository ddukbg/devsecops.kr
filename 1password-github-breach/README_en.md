# What the 1Password GitHub breach teaches about CI/CD and developer-account supply chain defense

[한국어](README.md) | [English](README_en.md)

On November 25, 2026, 1Password disclosed a breach of its backend systems. A single **employee corporate GitHub account** was taken over and used to copy private source code, reach the **CI/CD system**, push **malicious code to backend services**, and, through that code, download account records for a subset of customers. Customer vaults stayed out of reach thanks to the zero-knowledge design — but the attack path itself reproduces in any organization.

> One developer account → source code → CI/CD → production backend.
> If nothing gates the path between a **person's account and deploy rights**, the same chain works whether or not you sell a password manager.

## At a glance

| Item | What is confirmed |
| --- | --- |
| Detection | 2026-11-19; investigation began after indications of unauthorized access to an employee's corporate GitHub account |
| Disclosure | 2026-11-25 (1Password official blog) |
| Path | Compromised employee GitHub account → private repository source code copied, CI/CD system accessed, malicious code pushed to backend services → customer administrative data downloaded |
| Data taken | Names and email addresses, account and user identifiers, account creation and last sign-in times, public keys, SRP parameters, invitation/provisioning/account recovery email tokens, non-secret internal metadata (version and file numeric identifiers) |
| Not taken | Customer vault contents and items, vault-protecting keys, account recovery keys, 1Password apps and browser extensions |
| Scale | Described as "a subset" of customers; **the exact count has not been published** |

## 1. What happened

- 1Password began investigating on **2026-11-19**, after detecting indications that an employee's corporate GitHub account had been compromised.
- With that account, the attacker **accessed source code in private repositories** and **pushed malicious code to backend services**. The pushed code **downloaded** customer administrative data.
- The same account gave the attacker **access to the CI/CD system**. 1Password stated that CI/CD holds infrastructure secrets needed to run the product, and it **rotated all potentially exposed credentials**.
- Vaults, vault items, vault-protecting keys, and recovery keys were not exposed because of the zero-knowledge design. 1Password does not store account passwords or Secret Keys.

## 2. What leaked and what stayed safe

| Class | Item | What it means in practice |
| --- | --- | --- |
| **Taken** | Names, sign-in email addresses | A list of known 1Password users — raw material for **targeted phishing** |
| **Taken** | Account and user identifiers, creation and last sign-in times | Lets an attacker confirm accounts and infer activity patterns |
| **Taken** | Public keys, SRP protocol parameters | Public by design; cannot be used to reach an account |
| **Taken** | Tokens in invitation, provisioning, and recovery email links | Not usable alone. **SSO sign-in or a code sent to the registered email** is also required |
| **Taken** | Non-secret internal metadata (version/file numeric IDs) | Useful for mapping internal architecture |
| **Safe** | Vault contents and items, vault-protecting keys | Never reached the attacker's server |
| **Safe** | Account recovery keys, apps, browser extensions | No impact |
| **Taken (company asset)** | Private source code, CI/CD infrastructure secrets | Not customer data, but includes **infrastructure credentials** |

> The last line is the point. Vaults survived because of the encryption design, and the incident stopped where it did because of **credential rotation**. An organization without the same design gets a different outcome from the same attack.

## 3. How 1Password responded

- Disabled the affected GitHub account, revoked the stolen token, and removed the access the attacker created
- Rotated or revoked **all internal credentials** that may have been exposed
- Restored clean versions of the affected services
- Lengthened invitation and recovery email codes from **six numeric digits to ten alphanumeric digits** (brute force becomes impractical)
- Tightened internal GitHub, CI/CD, and endpoint controls, and added new detections for this attack
- Brought in independent security experts to validate containment and remediation; found **no internal evidence of account takeover** using provisioning tokens
- Required no customer action, but warned about **phishing that impersonates invitations and account recovery**

## 4. Still unknown as of 2026-11-26

- **How the employee account was compromised** (malware, session token theft, phishing — the initial access vector) — not in the official notice
- **Whether the backend deploy gates held** — whether the malicious push passed pull request review, branch protection, and deploy approval, or bypassed them
- **Number of affected customers** — only "a subset" is stated
- **Attacker attribution** — not disclosed
- Details of the token TTL and reuse policy for invitation/recovery links

These can change as the notice is updated. In internal reports, leaving them labeled "not disclosed" is safer.

## 5. Where to block first

1. **Do not let a person's account equal deploy rights.** If a personal GitHub account can deploy to production, that account *is* production access.
2. **Ban force-push on deploy branches.** Campaigns such as `PolinRider`, which plant loaders into open-source pull requests by force-push, rely on rewriting a branch.
3. **Remove long-lived keys from CI/CD.** If a cloud access key sits in repository secrets, write access to that repository becomes your entire cloud permission set.

## 6. Four controls worth putting in place

### ① No classic PATs — fine-grained PATs with org SSO and passkeys

- Block **classic PAT** issuance at the organization level; run fine-grained PATs with **approval and a mandatory expiry**.
- Require **SAML SSO or passkeys** for members, and enforce 2FA organization-wide.
- Review the credentials that remain on a schedule (requires org admin).

```bash
# Fine-grained PATs approved for the org (owner, repository scope, expiry)
gh api "orgs/ORG/personal-access-tokens?per_page=100" \
  --jq '.[] | [.owner.login, .repository_selection, (.token_expires_at // "unset")] | @tsv'

# Credentials authorized through SSO (classic PATs, SSH keys, deploy keys)
gh api "orgs/ORG/credential-authorizations?per_page=100" \
  --jq '.[] | [.login, .credential_type, (.credential_authorized_at // "-")] | @tsv'
```

### ② No direct pushes to `main` or deploy branches — two reviews, CODEOWNERS, signed commits

- Forbid **direct pushes, force-pushes, and branch deletion** on deploy branches.
- Require **at least two approvals** together with **CODEOWNERS review**. A single approval collapses when one account falls.
- Require **verified commits**, so commits made with a stolen account cannot blend into history.
- Apply the rules to admins too (`enforce_admins`). Exceptions are the first thing abused during an incident.

```bash
# Inspect protection on the default branch
gh api repos/ORG/REPO/branches/main/protection \
  --jq '{approvals: .required_pull_request_reviews.required_approving_review_count,
         codeowners: .required_pull_request_reviews.require_code_owner_reviews,
         signatures: .required_signatures.enabled,
         enforce_admins: .enforce_admins.enabled,
         force_push: .allow_force_pushes.enabled}'
```

### ③ Remove static CI/CD keys — OIDC short-lived credentials with manual approval for production

- Obtain cloud credentials through **OIDC short-lived tokens** instead of long-lived repository secrets (AWS `AssumeRoleWithWebIdentity`, GCP Workload Identity Federation, Azure federated credentials).
- Keep the default workflow token **read-only** and raise permissions only in the job that needs them.

```yaml
permissions:
  contents: read
  id-token: write   # for OIDC short-lived credentials
```

- Put **required reviewers (manual approval)** on the production GitHub Environment. Even if CI is compromised, a human stands at the last gate.
- Review secrets by **name and last-updated time** only. Values are never returned by the API.

```bash
gh api "repos/ORG/REPO/actions/secrets?per_page=100" --jq '.secrets[] | [.name, .updated_at] | @tsv'
gh api "repos/ORG/REPO/environments" \
  --jq '.environments[] | [.name, ((.protection_rules // []) | map(.type) | join(","))] | @tsv'
```

### ④ Short TTLs for invitation and recovery tokens, codes of ten characters or more, and phishing guidance

- Issue invitation, provisioning, and recovery link tokens as **single-use with a short TTL (e.g. 15–60 minutes)**, and **rate-limit** the verification endpoint.
- Make codes long enough to be unguessable. This is why 1Password moved from six numeric digits to **ten alphanumeric characters**.
- Require **two or more factors** (token plus code plus SSO), and **notify the account owner** whenever an invitation or recovery is issued.
- In the incident notice, state plainly that "we never ask for your password or Secret Key" and give a **reporting channel**.

## 7. The check script in this repository

`audit_github_cicd.sh` covers items ①–③ with the `gh` CLI and only ever **reads**. It calls no write API.

```bash
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/1password-github-breach/audit_github_cicd.sh
bash audit_github_cicd.sh ORG/REPO
bash audit_github_cicd.sh ORG/REPO --branch main --branch release
```

- Checks: repository basics → default branch protection (approvals, CODEOWNERS, signed commits, force-push) → rulesets → Actions token permissions → secret names and update times → environment approvals → deploy keys → org fine-grained PATs and SSO credentials → static keys, OIDC, and `pull_request_target` in workflow files
- Organization-wide queries need **org admin**; without it, the script marks the item `[UNKNOWN]` and continues.
- It does not change any verdict. It only reports; you apply the change under your own policy.

## 8. If your team or you use 1Password

- **No password or Secret Key change is needed** (per 1Password). Vaults and keys were not exposed.
- Watch for **emails impersonating invitations and account recovery**. Do not click; open the 1Password app or type the official address yourself.
- 1Password **never asks for your password, Secret Key, or verification code**. Any contact that does is impersonation.
- Report suspicious messages to `support@1password.com`.
- If you run 1Password with SSO internally, also review the IdP session and SCIM provisioning tokens tied to the compromised account.

## Sources

- 1Password — Update on a security incident involving 1Password's backend systems (2026-11-25): https://1password.com/blog/update-on-nov-2026-security-incident
- BleepingComputer — 1Password customer data stolen after employee GitHub account breach (2026-11-25): https://www.bleepingcomputer.com/news/security/1password-customer-data-stolen-after-employee-github-account-breach/
- The Hacker News — 1Password Hacked, Customer Data and Source Code Stolen in GitHub Account Breach (2026-11-26): https://thehackernews.com/2026/11/1password-hacked-customer-data-and.html

Verification date: 2026-11-26. Scope and impact figures may change as the investigation and notices are updated; check the vendor advisory as well.
