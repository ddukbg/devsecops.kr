# Korean data breaches in November 2026 — shared entry points and a checklist

[한국어](README.md) | [English](README_en.md)

This document collects breaches confirmed in Korea's finance, public, retail, and education sectors between late September and November 2026. What matters more than the size of each incident is **where the attacker got in**. The core account systems held; external vendors, VOC attachments, legacy integrations, and merchant/settlement endpoints were breached repeatedly.

The 26 November additions (CJ Olive Young, Danawa, Suhyup Bank), the Hotel Story repeat breach and the KEPCO data trade, and five overseas cases from the same period are in sections 2-1 and 2-2.

> Compiled from press reports and regulator announcements; investigations may change the details. Verified as of 2026-11-27.

## 1. Financial sector — 37 companies, 40 incidents, 473,000 records

- Between **2026-09-30 and 11-03**, 37 financial companies reported 40 breaches. Names, resident registration numbers, and account numbers of **about 473,000 people** leaked.
- The Financial Services Commission (FSC) launched a full inspection of 580 financial companies. Shinhan Bank raised its 2027 security budget to KRW 115 billion (about 2.8× this year); Hana, Woori, and KB Kookmin each allocated KRW 100 billion or more plus SIEM/SOAR.
- Attack surface: core account systems (not directly breached; segregation and internal controls held) / **missing authorization checks in sales-support and loan-broker query APIs** / employee mobile and groupware authentication and session management / **outsourced and third-party integration servers**.

Source: FSC press release https://www.fsc.go.kr/no010107/88096 (2026-11-06)

## 2. Major incidents

| Incident | Date | Scale | Entry point |
| --- | --- | --- | --- |
| KEPCO (KEPCO ON, SRM) | November | **1,520,248** | No authorization or bulk-query limit on public web/API |
| Daishin Securities | 10/17 | 38,490 | Malware on a DMZ server → admin API key theft → repeated calls with a valid token |
| Mirae Asset mobile web | 11/04 | ~3,800 accounts | Account lookup by parameter tampering alone (no owner check) |
| Mirae Asset groupware | 11/05 | 35,255 | SQL injection |
| Samsung Securities VOC | 11/21 | 8,241 | Missing authorization on VOC attachments |
| Jeonju University | November | 180,000+ | Weak linkage between the liberal-arts system (AHA) and the old website |
| Kurly | November | 10,699 curators + 199 employees + 2 customers | Credential theft |
| LK·HWS insurance brokerage | November | 66 at Yebyeol Sonbo, 10 insurers linked | Vulnerability in a contracted group-insurance claims system |
| HD Hyundai Robotics | November | Under investigation | 10 fields from website sign-ups |
| Korea Information & Communications (KICC) | 11/20 17:31 | Undisclosed | Merchant/seller data, partner simple-payment transactions |

### Five newly confirmed in November

- Sunchon National University — external intrusion into the old Hyangnim Tong system (scale under review)
- Welcome Payments — 1,326 people (including **billing keys** for automatic payments)
- KIS Information & Communications — up to 862 people via a VAN web server
- NHN KCP — 160 sales receipts viewed; FSC convened payment gateway operators
- Hana Savings Bank — 552 people via mobile web (19 fields including resident numbers)

Confirmed November volume exceeds **2.14 million records** (KEPCO 1.52M, Nonghyup Noranwoosan 360K, Jeonju University 180K, POSTECH 45K, Daishin/Mirae 77K+, Inje University 24K, Kurly 10K+, Samsung Securities 8,241, KOMSCO 3,000+, MetaM→Coinone, FSS, Seoul Central District Court PDFs, Yebyeol Sonbo, etc.). CJ Olive Young's 2,406,338 internal member-number records are a different class of data and are not added to this total.

### 2-1. Added on 26 November — back office, outage, repeat breach, data trade

| Incident | Date | Scale | Entry point |
| --- | --- | --- | --- |
| CJ Olive Young back office | notice 11/26 (intrusion 11/23) | **790 people** personal data + **2,406,338** internal member-number records | Unauthorized external access to the back-office system |
| Danawa (ConnectWave) | from 11/26 02:00 | leak **unconfirmed** | Suspected external compromise → web/app down 15+ hours |
| Sh Suhyup Bank | reported to FSS 11/26 | **54** customers | Loan/credit/address lookups — brute-forced verification code suspected |
| Hotel Story (booking solution) | 2nd breach 11/22 (confirmed 11/23) | **undisclosed** | Own system vulnerability — 27 days after the 10/26 breach |
| KEPCO leaked data on sale | listing 11/23 (reported 11/26) | hacker claims **1.04M records** | Sold on a Telegram channel — **KRW 500 per record** |

**CJ Olive Young** — an external party gained unauthorized access on 23 November. Names, emails, mobile numbers and birth dates of 639 employees, 106 partner-company staff and 45 customers (790 in total) were exposed, along with **2,406,338 internal member-number records** (2,344,549 member numbers alone; 61,789 with member number and access IP). Payment data and passwords were not exposed; the company says it isolated the system, revoked accounts and reported to the authorities. The practical lesson is the **back-office account and the internal identifier**, not the customer app. The checklist is in [`cj-oliveyoung-breach`](../cj-oliveyoung-breach/README_en.md).

**Danawa** — web and app services went down at 02:00 on 26 November and stayed down for 15 to 17+ hours depending on the report. The company suspects an external compromise and is investigating whether personal data leaked and at what scale. **Keeping confirmed and unconfirmed facts apart is the point here** (an unconfirmed leak is not "no leak"). User and operations checklists are in [`danawa-service-outage`](../danawa-service-outage/README_en.md).

**Sh Suhyup Bank** — on the afternoon of 26 November the bank confirmed that loan data, credit information and addresses of 54 customers had leaked and reported to the Financial Supervisory Service. Attackers made repeated connections with many resident registration numbers; the numbers alone were not enough, but they **guessed the additional verification service code by brute-forcing random values**. The source is believed to be an overseas IP and the path is under investigation. This makes Suhyup the **fifth** bank with confirmed customer data loss in the suspected AI-assisted campaign, after Shinhan, KB Kookmin, Hana and BNK Busan. It is separate from the 17 October Pukyong National University tuition-system incident (5,108 people).

> Lesson from Suhyup: **resident number + a short numeric code** does not survive brute force. Put per-user attempt limits, failure delays and anomaly detection on the lookup API, and route bulk lookups through a separate approval flow.

**Hotel Story** — a hotel booking-management vendor (PMS, channel manager, booking engine) suffered a **second breach on 22 November** through a vulnerability in its own system, 27 days after the first one on 26 October, and confirmed the leak on 23 November. The second round exposed booking records (name, mobile or proxy number, email, booking number, status, stay details) and booking-engine member accounts (name, phone, email). Anyone whose booking was processed through Hotel Story can be affected even without an account there, yet the company has not published the list of affected hotels and booking channels or the total number of records. The first breach came through exposed hotel account credentials; the second through the vendor's own vulnerability — password resets and access reviews did not remove the flaw itself. Stay records reveal travel and occupancy patterns, so fake cancellation or extra-payment messages quoting a real booking number deserve extra suspicion.

**KEPCO leaked data on sale** — on 23 November a hacker listed KEPCO customer data for sale on a Telegram channel, and SBS reporters posing as buyers found the samples were from this breach. The seller claims to hold about **1.04 million records**, of which 200,000 include name, bank account, resident number, phone and address, at **KRW 500 per record**. KEPCO confirmed that the data on sale came from this attack. Material previously traded on the dark web has moved to a mainstream messenger, lowering the barrier for phishing and voice-phishing built on the leaked fields.

### 2-2. Five overseas cases in the same period — all started with credentials

| Incident | Date | Scale / impact | Starting point |
| --- | --- | --- | --- |
| 1Password | 11/19 | Customer names, login emails, invite/recovery tokens; vaults and encryption keys not exposed | Employee corporate GitHub account → CI/CD and backend malware |
| Rackspace Spot | compromised 11/17 → **service ends 12/8** | Customer pods created, Secrets read | Stolen credentials |
| Defang | compromised 11/12 → disclosure 11/24 | Main database copied (names, emails, repo names, DB passwords in deployment state) | An **over-permissioned development GitHub App** → CI that trusted release tags |
| Hex.pm | 11/23 | Commands run on 6 servers; no package tampering found | **Deserialization RCE reachable unauthenticated** (`CVE-2026-129514`, CVSS 10.0) |
| EU Commission | from 10/22 | Sysper and EU Academy offline; names and emails exposed | Suspected ARTEX (Storm-0940) — AI-agent-linked supply chain |

- **1Password**: an employee's corporate GitHub account was compromised, leading to private source code and CI/CD access and malware in the backend. Four controls and an audit script are in [`1password-github-breach`](../1password-github-breach/README_en.md).
- **Rackspace Spot**: stolen credentials were used to create pods in customer clusters and read Secrets; the platform confirmed it will shut down on 8 December. IoCs and key-rotation order are in [`cloud-secrets-exposure`](../cloud-secrets-exposure/README_en.md).
- **Defang**: a development and testing GitHub App held more permissions than it needed, including the ability to change deployment environments. Acting as that app, the attacker pushed a commit tagged as a release, and **production CI that trusted release tags** ran it with production credentials. Those credentials stayed valid until they were replaced on 23 November (company disclosure).
- **Hex.pm**: the `application/vnd.hex+erlang` body parser accepted maps with a `__struct__` key, which made deserialization RCE possible before routing and authentication. Six servers were affected by 69 requests; the company deployed a server-side patch **within 20 minutes** and rotated credentials. Users were told to reset passwords and 2FA.
- **EU Commission**: attributed to an AI-agent-linked campaign (ARTEX/Storm-0940), ongoing since 22 October; no evidence that all staff data leaked. Analysis links are in [`ai-agent-attacks`](../ai-agent-attacks/README_en.md).

## 3. Where to check exposure

- KEPCO: https://online.kepco.co.kr — dedicated breach lookup
- Jeonju University: https://www.jj.ac.kr/jj/community/notice01.do?articleNo=535915
- Samsung Securities: "Personal (credit) information breach lookup" menu on the website
- FSC, Personal Information Protection Commission announcements, and each company's notice

## 4. Internal checklist

### 4-1. Query APIs — BOLA/IDOR

- [ ] Every query API verifies **session user == resource owner** (never query by a supplied ID alone)
- [ ] Resource IDs are unguessable (UUID v4, not sequential numbers)
- [ ] List/search APIs apply the same owner scope (test filter bypass)
- [ ] Bulk queries limited by **user/token cardinality**, not only by IP
- [ ] Abnormal bulk SELECT detected and blocked by WAF/DAM

### 4-2. Attachments (VOC, boards, support)

- [ ] Each download API checks author and permission
- [ ] S3/NAS buckets private; files served only through **short-lived presigned URLs**
- [ ] Automatic masking and retention-based deletion for ID cards, bank copies, and other unstructured attachments
- [ ] Attachment URL guessing and reuse tests included in pre-deploy checks

### 4-3. Legacy and external entry points

- [ ] Inventory of retired systems, old websites, and subdomains; block external exposure
- [ ] Separate API keys per vendor/contractor, IP restrictions, usage monitoring
- [ ] MFA on groupware and mobile web, session expiry, abnormal-location login blocking
- [ ] Minimize and periodically re-approve network segregation exceptions

### 4-4. Payments and settlement (KICC response)

- [ ] Reconcile **all merchant settlement-account changes since 11/20** against actual deposits
- [ ] Re-check partner simple-payment and VAN API keys, webhook signatures, and IP allowlists
- [ ] Warn merchants about **settlement-account-change phishing** using company name, CEO name, and MID

### 4-5. Three rules for external entry points — ACT · ROT · LOG

Three things this month's incidents keep pointing at.

| Rule | What to do | How to judge it |
| --- | --- | --- |
| **ACT** | **Inventory every external entry point**, including domains, legacy systems, admin pages and back offices | Use certificate transparency and subdomain enumeration to find assets you forgot; remove DNS records of retired systems |
| **ROT** | **Rotate keys, tokens and credentials on a schedule** | Rotate by issuing authority, then confirm in CloudTrail/audit logs that the old ones are unused; move CI to OIDC |
| **LOG** | **Keep authentication logs for external entry points for 90+ days** | Log successes and failures, and wire bulk lookups, odd hours and overseas IPs into detection rules |

> The three rules do not create new controls; they turn the assets, keys and logs you already have into **an inventory and a schedule**. Organizations that only build the inventory after a breach notice keep getting hit.

## 5. Common lessons

1. **The core database held; the surroundings fell.** External vendors, attachments, legacy integrations and back offices are repeated entry points.
2. **A valid token passes authentication even when abused.** Authorization and usage anomaly detection are required — and a resident number plus a short code does not survive brute force (Suhyup).
3. **Breach numbers only grow.** KEPCO found 35,000 more people a month later. Do not treat the first announcement as final.
4. **All five overseas cases started with credentials.** Unless repository permissions, CI trust conditions and static keys are reduced together, the same shape repeats.
5. **Leaked data reaches a market after the notice.** Three days after KEPCO's announcement, its leaked records were on sale on Telegram at KRW 500 each. Run impersonation and phishing detection on the leaked fields and identifiers, and keep customer guidance running well past the incident's formal close.

## References

- FSC — 37 companies, 473,000 records; full inspection of 580 companies: https://www.fsc.go.kr/no010107/88096
- Yonhap — KEPCO 1.52 million: https://www.yna.co.kr/view/AKR20261122042800003
- Digital Times — KEPCO: https://www.dt.co.kr/article/12096557
- Yonhap — Samsung Securities VOC 8,241: https://www.yna.co.kr/view/AKR20261123060751008
- Daily Secu — Samsung Securities: https://www.dailysecu.com/news/articleView.html?idxno=209660
- Asia Today — Daishin/Mirae 77,000: https://www.asiatoday.co.kr/kn/view.php?key=20261123010008969
- Yonhap — Daishin/Mirae: https://www.yna.co.kr/view/AKR20261028068951008
- ETNews — KICC merchant data breach: https://www.etnews.com/20261125000064

### Added on 26 November

- CJ Olive Young — official notice: https://corp.oliveyoung.com/ko/newsroom/press/383
- Yonhap — CJ Olive Young, 790 people and member-number records: https://www.yna.co.kr/view/AKR20261126192200030
- ETNews — Danawa outage: https://www.etnews.com/20261126000392
- ZDNet Korea — Danawa outage, cross-check: https://zdnet.co.kr/view/?no=20261126153610
- Money Today — Suhyup Bank, 54 customers; fifth affected bank: https://www.mt.co.kr/finance/2026/11/26/2026112618003425503
- Insight Korea — Suhyup Bank, second incident within a month: https://www.insightkorea.co.kr/news/articleView.html?idxno=259891
- Daily Secu — Hotel Story second breach (11/22), booking-engine member data: https://www.dailysecu.com/news/articleView.html?idxno=209782
- Daily Secu — Hotel Story first breach (10/26): https://www.dailysecu.com/news/articleView.html?idxno=209143
- SBS — KEPCO leaked data traded on Telegram at KRW 500 per record: https://news.sbs.co.kr/news/endPage.do?news_id=N1008865831
- KBS — KEPCO data on the dark web, bid information claimed: https://news.kbs.co.kr/news/pc/view/view.do?ncd=8720600

### Overseas cases

- 1Password — Update on Nov 2026 security incident: https://1password.com/blog/update-on-nov-2026-security-incident
- BleepingComputer — Rackspace shuts down Spot after security breach: https://www.bleepingcomputer.com/news/security/rackspace-shuts-down-spot-cloud-platform-after-security-breach/
- Defang — Security incident: November 2026: https://defang.io/blog/post/security-incident-november-2026/
- Hex — Security incident on hex.pm: https://hex.pm/blog/security-incident-on-hexpm
- GitHub Advisory — GHSA-9pmm-hf4r-27pg (CVE-2026-129514): https://github.com/hexpm/hexpm/security/advisories/GHSA-9pmm-hf4r-27pg
- Euronews — EU Commission cyberattack: https://www.euronews.com/2026/11/23/exclusive-china-backed-hackers-suspected-behind-ongoing-eu-commission-cyberattack
