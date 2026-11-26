# CJ Olive Young back-office breach: 790 people's data and 2.4 million member-number records

[한국어](README.md) | [English](README_en.md)

On 23 November 2026, an external party gained unauthorized access to CJ Olive Young's **internal work system** (back office). On 26 November the company published a notice confirming that personal data of **790 people** had been leaked, along with **2,406,338 records of internal member numbers**. Payment data and passwords were not exposed, the company said.

> This was not a case of a shopping-mall member database being taken wholesale. Someone got into the **back-office** through an internal account and pulled internal administrative data out.
> So the questions for practitioners are: how far did login controls on the work system actually reach, and why was an internal identifier like a member number sitting in that quantity, in that place.

## At a glance

| Item | Detail |
| --- | --- |
| Incident date | 23 November 2026 (unauthorized access) |
| Disclosure | 26 November 2026, corporate website / newsroom |
| Entry point | Company **work system** (back office), separate from customer-facing account login |
| People whose data leaked | **790** — 639 employees, 106 partner-company staff, 45 ordinary customers |
| Leaked fields | Member number, and for some: name, IP address, member ID, phone number, date of birth, email — **varies by person** |
| Separate dataset | Internal member-number records, **2,406,338**: 2,344,549 with member number only, 61,789 with member number and access IP |
| Payment data, passwords | **Not exposed** (company statement) |
| Response | Network isolation, blocking the intrusion path, revoking and disabling the account used, discarding and rotating stored credentials, strengthening login authentication |
| Notifications | Reported to KISA and the Personal Information Protection Commission; affected customers notified |
| Verified as of | 27 November 2026, 03:00 KST |

## 1. Timeline

| Time (KST) | Event | Source |
| --- | --- | --- |
| 2026-11-23 | Unauthorized external access to the internal work system; personal data in some files leaked | CJ Olive Young notice |
| 2026-11-26, ~21:00 | Notice "고객 개인정보 유출에 대한 사과 및 안내" (apology and guidance on customer data leak) published with scope, fields and response | Company notice, Yonhap |
| 2026-11-26 21:22 | Seoul Economic Daily reports 790 people plus the 2,344,549 / 61,789 record split | Seoul Economic Daily |
| 2026-11-26 22:50 | Hankyung reports the same figures, with the company's statement that member numbers are internal serial numbers that alone do not identify a person | Hankyung |
| 2026-11-27 00:16 | Open News Communications reports the warning about impersonation texts and calls | Open News Communications |

## 2. Confirmed facts

- **The entry point was the "work system"**: the notice says only "unauthorized external access to the company's work system." Which system, and which weakness was used, was not disclosed.
- **790 people affected**: 639 employees, 106 partner staff, 45 customers. Customers are about 6% of that — the primary target looks like the back office and the data attached to it, not the customer database.
- **Fields differ by person**: member number in all cases; for some, name, IP address, member ID, phone number, date of birth and email as well.
- **A separate 2.4 million-record dataset**: 2,344,549 records containing member numbers only, plus 61,789 records containing member number and access IP.
- **The company's description of member numbers**: internal serial numbers that alone make identification difficult (Hankyung). The 61,789 records that also carry an IP address sit outside that comfort.
- **Payment data and passwords were not exposed.**
- **Response**: network isolation and blocking of the intrusion path; the attacker's account revoked and disabled; stored access credentials discarded and replaced; internal login method changed and authentication strengthened.
- **Reported and notified**: KISA and the Personal Information Protection Commission, plus individual notification to affected customers.

## 3. Not yet confirmed (as of 27 November 2026, 03:00 KST)

| Item | Status |
| --- | --- |
| Initial intrusion path and exploited weakness | Not disclosed |
| Attacker identity, affiliation, demands | Not disclosed |
| Exact type of work system, owning team, connected systems | Not disclosed |
| Original purpose of the member-number dataset (marketing, CS, partner settlement) | Not disclosed |
| Actual volume of secondary harm (phishing, impersonation) | Not confirmed |
| Whether employee or partner accounts were additionally compromised | Not confirmed |

These will change as the notice is updated. When citing in an internal report or customer notice, **leaving them as "not disclosed" is the safer choice.** "2.4 million customer records were stolen" is not what the notice describes.

## 4. What the official notice says

Title: "고객 개인정보 유출에 대한 사과 및 안내" (2026.11.26). Six points:

1. Unauthorized external access to the work system on 23 November 2026; personal data in some files confirmed leaked.
2. Protective measures completed immediately — network isolation and intrusion-path blocking; the account used revoked and disabled; stored access credentials discarded and replaced; login method changed and authentication strengthened.
3. Report to authorities and cooperation with the investigation.
4. Leaked fields — member number, and for some: name, IP address, member ID, phone number, date of birth, email.
5. What customers can do — be wary of texts, emails and calls impersonating Olive Young, avoid unknown links and app installs, contact the customer center (080-120-0882, 09:00–18:00 daily).
6. Remedies — damages under Article 39 of the Personal Information Protection Act, statutory damages under Article 39-2, or dispute mediation via the Privacy Infringement Report Center (118) and the Personal Information Dispute Mediation Committee (1833-6972).

## 5. The practitioner's read

1. **The back office is still the weakest door.** Customer-facing services get WAFs, bot blocking and rate limits layered on them, while internal work systems and admin consoles are often one VPN or one account away. That 745 of the 790 people were employees or partner staff points at that structure.
2. **Where internal identifiers live sets the blast radius.** A member number alone may not identify anyone, but if member ID, phone number and IP sit on the same server, the combination does. "Not identifiable" holds only while that dataset **stands alone**.
3. **Bulk reads are the quietest signal of an attack.** Pulling 2.34 million records leaves a pattern unlike normal business activity — by account, by hour, by volume. Without detection rules on those axes, you learn about it afterwards, from logs.
4. **Rotating credentials presumes the account was taken.** Revoking and disabling, discarding stored credentials, changing the login method — those are the steps you take when you assume the password or keys are in someone else's hands. If that account was reused elsewhere, those systems need the same treatment.
5. **Three days to disclosure.** Access on the 23rd, notice on the 26th. Korean law requires notification without delay after awareness (and reporting within 72 hours for breaches over 1,000 people), so the **recorded time of awareness** is what the after-the-fact judgment rests on.

## 6. User checklist

- Check whether your Olive Young password was reused on other sites or work accounts. If it was, change it now.
- Do not click links in texts, emails or calls claiming to be about "Olive Young data leak confirmation," "compensation," or "identity verification." The company pre-announced this channel in its notice.
- If a password-reset email arrives, go to the Olive Young app or site directly rather than through the mail's link.
- Compare the delivery address and phone number you registered with recent delivery-scam or smishing messages.
- Report suspicious contact or harm to the Olive Young customer center (080-120-0882) or the Privacy Infringement Report Center (118).

## 7. Operator checklist (DevSecOps)

### Internal work systems and back office

- **Make MFA the default for admin and internal systems.** Keep exception accounts in a list, each with an expiry.
- **Restrict by allowed IP range and device** (device certificates). Block or require separate approval for logins from outside office and VPN ranges.
- **Minimize permissions by job function.** Separating read from export means the people who can see data and the people who can take it are not the same set.
- **Automate account removal** on departure, transfer and partner-contract end. That 106 partner accounts touched personal data is itself worth an audit.

### Internal administrative data

- **Do not keep member-number or customer-identifier datasets in plaintext on local disks or shared folders** of the work system. Serve lookups through an API; put bulk export behind an approval step.
- **Add bulk read/export detection** on account, hour and volume. Examples: more than 100,000 rows in one request, 10× typical volume, repeated late-night pulls.
- **Centralize logs including access IP**, with a defined retention period. This incident itself involved a dataset of member number plus IP.
- **Mask and tokenize**: use tokens instead of raw member numbers in screens and spreadsheet exports, and keep the mapping table in a separately controlled zone.

### Incident response

- **Record the time of awareness** — it starts the notification clock.
- **Pre-write an impersonation-channel notice template.** Push the same wording through SMS, app push, website and call-center script at the same time as the leak notice; that is what cuts secondary harm.
- **Bulk credential rotation runbook**: invalidate sessions → force password reset → rotate API keys and service accounts → verify connected systems. Fix the order in a document, not in the moment.

## Sources

- CJ Olive Young newsroom — apology and guidance on customer data leak (2026-11-26): https://corp.oliveyoung.com/ko/newsroom/press/383 (checked 2026-11-27 03:04 KST)
- Yonhap — CJ Olive Young hit by work-system hack; employee and customer data leaked (2026-11-26 21:09): https://www.yna.co.kr/view/AKR20261126192200030
- Hankyung — "CJ Olive Young breached too… data on 790 people" (2026-11-26 22:50, updated 2026-11-27 00:42): https://www.hankyung.com/article/2026112634721
- Seoul Economic Daily — external intrusion into work system, 790 people's data (2026-11-26 21:22): https://www.sedaily.com/article/20119594
- JoongAng Ilbo — 790 people and about 2.4 million member-number records (2026-11-26 23:11)
- Open News Communications — name, phone, date of birth included (2026-11-27 00:16)

Verified as of 27 November 2026, 03:00 KST. The intrusion path, attacker and secondary harm are undisclosed; check the notice and latest reporting before citing.
