# KEPCO: encrypted at rest, leaked in plaintext

[한국어](README.md) | [English](README_en.md)

On 28 November 2026, South Korean MP Cha Gyu-geun (Rebuilding Korea Party, Industry/Trade/SME Committee) published data submitted by KEPCO (Korea Electric Power Corporation). It showed that personal data KEPCO had **encrypted at rest was exfiltrated in decrypted, plaintext form** from both the KEPCO ON customer platform and the electric procurement system (SRM). In the same submission KEPCO answered that it found **"no evidence of key leakage or unauthorized access to encryption keys."**

In other words, the ciphertext left as plaintext without anyone stealing a key. This document lists the confirmed facts, the structure that makes this possible, and a checklist to test whether the same path is open in your systems.

## At a glance

| System | Records | Fields that left in plaintext | Fields stored encrypted |
| --- | --- | --- | --- |
| KEPCO ON (billing / account portal) | **650,487 customers** (7.1% of 9.2M users) | **all 12 fields** | resident / foreigner registration number, bank account, card number |
| SRM (procurement) | **869,761 users notified** (426,827 corporate representatives + 442,934 employees) | corporate representatives' resident / foreigner registration number, **426,827 records** | corporate representatives' resident / foreigner registration number |
| Encryption keys | — | **no leakage or unauthorized access found** | KEPCO ON: separate key server; SRM: logically separated, double-encrypted |
| Confirmed as of | 2026-11-28 | | |

KEPCO ON's 12 leaked fields: customer number, name, resident/foreigner registration number, phone, address, bank name, bank account, account holder, card issuer, card number, card holder, billing information.

## Timeline (KST)

| When | Event |
| --- | --- |
| 2026-10-04 | 35,528 employees, former employees and contractors exposed. KEPCO: "customer data is managed and protected separately in a dedicated system." |
| 2026-11-19 | Attacker emails KEPCO claiming data theft |
| 2026-11-20 | Dark-web posting and sample data confirmed → customer data breach confirmed (**47 days** after the employee incident) |
| 2026-11-22 18:00 | Reported to the Personal Information Protection Commission (PIPC); external IP access blocked, services suspended |
| 2026-11-23 | PIPC on-site inspection begins |
| 2026-11-27 | SBS reports the data being offered at **500 KRW per record** on Telegram; KEPCO confirms it is genuine |
| 2026-11-28 | MP Cha publishes KEPCO's answers — **even the encrypted-at-rest fields were plaintext** |

KEPCO had also answered PIPC that last year's privacy impact assessment of KEPCO ON produced **no improvement recommendations ("no defects")**.

## Why plaintext can leave without a key

Encryption at rest protects the bytes on disk. The service still has to show the value to someone, so it decrypts it somewhere — and everything after that point is plaintext.

```
[stored]  DB  ── ciphertext            ← only this layer is encrypted
            │  query
            ▼
[process] app / API  ── fetch key, decrypt, build response
            │
            ▼
[egress]  JSON / CSV / screen / log    ← already plaintext, no key needed
```

Typical paths:

- **BOLA / IDOR** — changing an object identifier in `GET /api/v1/customer/{no}` returns someone else's record. Predictable identifiers (customer number, contract number) make this worse.
- **Excessive field exposure** — the screen needs a masked phone number, but the response DTO ships the raw resident number and account number too.
- **Bulk read / export** — list APIs, Excel exports and batch reports that include unmasked values.
- **Logs and telemetry** — decrypted values written to debug logs, APM payloads or error traces.

"100% encrypted at rest" and "zero plaintext exposure" are different metrics. KEPCO's case is one where both were true at the same time.

## Checklist

### 1. Minimise, mask and tokenise responses

- [ ] Response schemas are explicitly defined; ORM entities are not serialised directly.
- [ ] Each screen and API returns only the fields it needs; features that truly need raw resident/account/card numbers are listed and reviewed.
- [ ] List, search and autocomplete responses carry no sensitive fields.
- [ ] Masking happens **server-side** (client-side masking means plaintext was already sent).
- [ ] Raw-value access requires separate permission, separate audit logging and approval.
- [ ] Serialisation filters keep plaintext out of logs, APM and error traces.

### 2. Object-level authorisation and volume controls

- [ ] Every read endpoint enforces **object-level** authorisation (does this subject own this object?), not just route/role checks.
- [ ] Identifiers are not sequential or guessable; use surrogate keys where possible.
- [ ] Per-user/IP/session rate limits and anomaly detection exist (many objects in a short window, sequential scanning).
- [ ] Alerts fire on off-hours bulk reads, new devices and foreign IPs.
- [ ] Insider, operations and batch accounts are audited on the same basis.
- [ ] Service accounts and human accounts use separate credentials and permissions.

### 3. Threat-model the decryption flow, not a "no defects" checklist

- [ ] Privacy impact assessments cover **where plaintext flows after decryption**, not only whether encryption is enabled.
- [ ] The data-flow diagram marks every decryption point (app servers, batch jobs, reports, downloads, external integrations, logs).
- [ ] For each decryption point: who can call it, what the response contains, and how often it can be called.
- [ ] Automated tests attempt cross-tenant / cross-user object reads and must fail.
- [ ] Adding new encrypted fields also adds masking and authorisation tests, so new fields cannot silently ship as plaintext.
- [ ] Incident response traces **where plaintext was produced**, not only whether keys leaked.

## Confirmed vs. not confirmed

**Confirmed:** scale and fields (KEPCO ON: 650,487 customers, 12 fields; SRM: 426,827 representatives' registration numbers), plaintext state at exfiltration, and no evidence of key leakage — all from KEPCO's answers to the committee and its PIPC filing. Regulators: PIPC investigation (11-23), Office for Government Policy Coordination reviewing a public-service inspection.

**Not confirmed:** the layer where plaintext was produced (application misuse, a flawed lookup API, an insider, batch/report jobs), the intrusion path and vulnerability class, attacker identity, and the real distribution volume of the leaked data. Nor which specific items the "no defects" assessment covered.

## Sources

- ZDNet Korea (2026-11-28) — https://zdnet.co.kr/view/?no=20261128120805
- Green Economic Newspaper (2026-11-28) — https://www.greened.kr/news/articleView.html?idxno=355832
- Insight (2026-11-27) — https://web.insight.co.kr/news/583915
- Yonhap (2026-11-22) — https://www.yna.co.kr/view/AKR20261122042851003
- Hankyoreh (2026-11-22) — https://www.hani.co.kr/arti/society/environment/1288534.html
- PIPC press release (2026-11-23) — https://pipc.go.kr/np/cop/bbs/selectBoardArticle.do?bbsId=BS074&nttId=12664

> Compiled from press and public disclosures. Needs updating once KEPCO's official investigation concludes. Confirmed as of 2026-11-28.
