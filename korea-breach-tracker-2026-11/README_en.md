# Korean data breaches in November 2026 — shared entry points and a checklist

[한국어](README.md) | [English](README_en.md)

This document collects breaches confirmed in Korea's finance, public, retail, and education sectors between late September and November 2026. What matters more than the size of each incident is **where the attacker got in**. The core account systems held; external vendors, VOC attachments, legacy integrations, and merchant/settlement endpoints were breached repeatedly.

> Compiled from press reports and regulator announcements; investigations may change the details. Verified as of 2026-11-26.

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

Confirmed November volume exceeds **2.14 million records** (KEPCO 1.52M, Nonghyup Noranwoosan 360K, Jeonju University 180K, POSTECH 45K, Daishin/Mirae 77K+, Inje University 24K, Kurly 10K+, Samsung Securities 8,241, KOMSCO 3,000+, MetaM→Coinone, FSS, Seoul Central District Court PDFs, Yebyeol Sonbo, etc.).

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

## 5. Common lessons

1. **The core database held; the surroundings fell.** External vendors, attachments, and legacy integrations are repeated entry points.
2. **A valid token passes authentication even when abused.** Authorization and usage anomaly detection are required.
3. **Breach numbers only grow.** KEPCO found 35,000 more people a month later. Do not treat the first announcement as final.

## References

- FSC — 37 companies, 473,000 records; full inspection of 580 companies: https://www.fsc.go.kr/no010107/88096
- Yonhap — KEPCO 1.52 million: https://www.yna.co.kr/view/AKR20261122042800003
- Digital Times — KEPCO: https://www.dt.co.kr/article/12096557
- Yonhap — Samsung Securities VOC 8,241: https://www.yna.co.kr/view/AKR20261123060751008
- Daily Secu — Samsung Securities: https://www.dailysecu.com/news/articleView.html?idxno=209660
- Asia Today — Daishin/Mirae 77,000: https://www.asiatoday.co.kr/kn/view.php?key=20261123010008969
- Yonhap — Daishin/Mirae: https://www.yna.co.kr/view/AKR20261028068951008
- ETNews — KICC merchant data breach: https://www.etnews.com/20261125000064
