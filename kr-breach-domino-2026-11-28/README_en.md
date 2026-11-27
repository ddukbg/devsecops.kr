# Four Korean breaches in four days — Korea Post, Danawa, E9pay, KOFST

[한국어](README.md) | [English](README_en.md)

Four breach disclosures confirmed in Korea between 25 and 28 November 2026, collected in one document. The sectors ran **postal (public) → commerce → remittance (fintech) → fund (finance)**. Facts that are confirmed and items not yet disclosed are kept apart.

> What matters to a practitioner is not "another one" but **what is confirmed, what is not**, and **whether the same window is open in our own systems**.

## At a glance

| Incident | When | Scale | Confirmed leaked fields | Status |
| --- | --- | --- | --- | --- |
| Korea Post (Internet Post Office) | lookups 17–24 Nov (detected 25 Nov 10:30) | **113,855 people** in one day's sample (incl. corporate) | name, address, phone number | full-period scope under investigation; service and non-member login suspended |
| Danawa (ConnectWave) | breach confirmed 25 Nov, service halted 26 Nov 02:00 | **undisclosed** | name, ID, mobile number, phone number | leak admitted; intrusion path and reopening date undisclosed |
| E9pay | 90+ attacks | **~KRW 2.5 billion** stolen | (no PII) merchant settlement funds | FSS on-site inspection; exact amount being verified |
| KOFST (Korea Federation of Science & Technology Societies) | 8 Nov 04:10 (detected 21:32) | **~210,000 records** | 16 fields (resident ID and password encrypted) | leak confirmed and notified; vulnerability unpublished |

## 1. Korea Post — registered mail recipient lookups

- Attackers reached the mobile **"change delivery address"** service and looked up recipients of registered mail in transit between 17 and 24 November: name, address and phone number.
- **113,855 people** (including corporate recipients) in the single day analysed so far; the full-period figure is still being determined.
- Detected 25 November 10:30 → reported to the Personal Information Protection Commission and referred to police.
- Mitigation: the change-address service and **non-member login** were suspended, and **all foreign IP addresses** were blocked from the mobile site.
- Not disclosed: full scope, the technical root cause, the attacker.
- The service is used by recipients who receive a delivery SMS. That non-member login also had to be suspended says something about the authentication model. Korea Post warns of **impersonation texts asking to change an address or pay extra delivery fees**; inquiries go to the postal customer centre (1588-1300).

## 2. Danawa — maintenance notice became a breach notice

| Time (KST) | Event |
| --- | --- |
| 25 Nov | ConnectWave confirms "unauthorised external access" caused a breach |
| 26 Nov 02:00 | Full service halt; first notice said "maintenance for stability and performance" |
| 26 Nov | Notice changed to "security incident suspected to be external intrusion" |
| 28 Nov | Apology notice confirms **partial member data leak** |

- Leaked fields: **name, ID, mobile number, phone number**. The company says passwords and payment data were not leaked.
- Not disclosed: volume, intrusion path, whether ransomware was involved, reopening schedule.
- Company advice: change the password anywhere the same one was reused; beware of Danawa-impersonating calls, texts and emails ("Danawa never asks for passwords or payment details by phone or text").

## 3. E9pay — 90+ attacks, ~KRW 2.5 billion

- The small-amount overseas remittance provider was hit **more than 90 times**, with about **KRW 2.5 billion** taken — the largest financial-sector loss in the recent wave.
- The money was mainly **settlement funds due to merchants**.
- The Financial Supervisory Service sent an on-site inspection team on 27 November; the exact amount is still being verified.
- The company had filed a securities registration statement for a KOSDAQ listing on 17 November.

## 4. KOFST — current and former members, ~210,000 records

| Time (KST) | Event |
| --- | --- |
| 8 Nov 04:10 | External attacker exploits a server vulnerability, accesses and reads member data |
| 8 Nov 21:32 | Breach detected (**17 hours later**) |
| 25 Nov 16:28 | Data leak confirmed (**17 days later**) |
| 26 Nov | Notice and apology posted |
| 27 Nov 09:00 | Individual text messages to affected members |

- Scale: **~210,000 records**, covering all current members (201,385 as of 2025) plus former members.
- 16 fields: member number, 13 internal identifiers, name (KR/EN), resident registration number (encrypted), date of birth, login ID, password (encrypted), mobile, email, work phone, work and home address, employer, department, title, join/leave dates.
- **Financial data is not in the leaked list.** The vulnerability type and encryption scheme were not published.
- Members are largely government-funded research institute staff, science ministry employees and engineering firms — the bulk of Korea's science and technology workforce.

## 5. Practitioner checklist

### A. Non-member and simple-parameter lookup APIs

- **Authorisation (BOLA/IDOR)**: verify on every request that the caller owns the record. Do not trust `?no=12345`; bind the lookup to the session subject.
- **Assume identifiers are guessable**: waybill, order and member numbers often follow a sequence. Randomise them or use single-use tokens.
- **Rate limiting**: per account, IP and device; detect and block rapid or bulk enumeration.
- **Minimise the response**: do not return name, address and phone together on one screen. Mask and require a separate confirmation step.
- **Foreign IPs as standing policy**: for a domestic-only service, default deny with explicit exceptions rather than blocking after an incident.
- **Logging**: keep access and authentication logs at least 90 days; alert on many lookups in a short window.

### B. Money-moving APIs (remittance, settlement)

- **Anomaly rules**: amount, count, new beneficiary account, time of day. Rate limiting and authentication do not stop 90 repetitions; transaction rules do.
- **Repeated-call blocking**: delayed settlement (hold) and step-up authentication for successive withdrawals in one session.
- **Separate credentials**: split operational and service accounts; service accounts get IP allowlists and least privilege.
- **Settlement account changes**: two-person approval, callback to the registered contact, 24-hour hold.

### C. Impersonation texts and calls

- The hours after disclosure are the riskiest. Publish the official channel first and tell employees and customers with the same wording.
- Never open "change your delivery address" or "pay the extra shipping fee" links. The Korea Post service is suspended; inquiries go to the customer centre.
- The same applies to Danawa and KOFST impersonation. State plainly that the company never asks for passwords or payment details by phone or text.

### D. Disclosure operations

- When a "maintenance" notice becomes a "breach" notice, say so at the moment you change it. Danawa's users knew only about maintenance for two days.
- Deadlines: breach reporting within **24 hours** of detection, and notification within **72 hours** for leaks affecting 1,000+ people.

## 6. Sources

- Korea Post: [Yonhap](https://www.yna.co.kr/view/AKR20261128000900017) · [Hankyung](https://www.hankyung.com/article/2026112858107) · [Hani](https://www.hani.co.kr/arti/society/society_general/1289501.html) · [Digital Times](https://www.dt.co.kr/article/12097685)
- Danawa: [ZDNet Korea](https://zdnet.co.kr/view/?no=20261128050855) · [ETNews](https://www.etnews.com/20261126000392) · [Newsis](https://www.newsis.com/view/NISX20261126_0003885067)
- E9pay: [Yonhap](https://www.yna.co.kr/view/AKR20261127162500002) · [Financial News](https://www.fnnews.com/news/202611272110342717) · [Chosun Biz](https://www.chosun.com/economy/stock-finance/2026/11/27/MQ3TGZLDGBRWCZTBGE3WMOBQGQ/)
- KOFST: [Yonhap](https://www.yna.co.kr/view/AKR20261127047651017) · [Maeil Business](https://www.mk.co.kr/news/it/12220350) · [Newsis](https://www.newsis.com/view/NISX20261127_0003885875) · [Money Today](https://www.mt.co.kr/tech/2026/11/27/2026112713354462030)

> Verified 2026-11-28 08:00 KST. Figures and scope may change as investigations proceed. Patch timing and operational decisions belong to your organization's security policy.
