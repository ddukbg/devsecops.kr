# Danawa full service outage — suspected external intrusion

[한국어](README.md) | [English](README_en.md)

From 02:00 KST on 26 November 2026, the Korean price-comparison platform **Danawa** has been fully offline. Its operator, **Connectwave**, first posted a "system maintenance" notice and then replaced it with a notice describing a **"security incident suspected to be an external intrusion."** As of 17:00 the outage had run past 15 hours with no recovery schedule announced.

> For users the urgent question is when the site comes back. For practitioners the urgent question is **what has actually been confirmed**.
> This document separates confirmed facts from open questions and keeps only the actions that make sense right now.

## At a glance

| Item | Detail |
| --- | --- |
| Outage start | 02:00 KST, 2026-11-26 (Connectwave notice, "outage period") |
| Duration | **15+ hours** as of 17:00 KST, 2026-11-26; no recovery schedule announced |
| Scope | Danawa web and mobile app. Services to be restored server by server as safety is verified |
| Nature | Connectwave: "security incident suspected to be an external intrusion" — not a confirmed breach |
| Response | Report filed with the relevant authorities; external security firm engaged |
| Personal data | **Unconfirmed**, under investigation. Customers will be notified per law if a leak is confirmed |
| Guidance to users | Change the password if reused elsewhere; watch for Danawa-impersonating calls, texts and emails |
| Verification point | 17:00 KST, 2026-11-26 (subject to change with new notices) |

## 1. Timeline

| Time (KST) | Event | Source |
| --- | --- | --- |
| 2026-11-25 | Connectwave announced a ChatGPT integration that compares prices, specs and sellers for Danawa products, covering roughly **1.4 billion** product records collected in real time from 50+ Korean e-commerce sites. The same integration went live on Anthropic's Claude in August | ZDNet Korea |
| 2026-11-26 02:00 | Danawa services suspended. The page at the time carried a "system maintenance for stability and performance" message | Connectwave notice, ZDNet |
| 2026-11-26 morning | Notice replaced with the "suspected external intrusion" statement; investigation into cause, scope and personal data | Connectwave notice |
| 2026-11-26 14:56 | Electronic Times breaks the story (13 hours in, data-leak status under review) | Electronic Times |
| 2026-11-26 15:39 | ZDNet Korea reports the maintenance-to-incident notice change, the day-after-ChatGPT-integration timing, and the statutory reporting clocks | ZDNet Korea |
| 2026-11-26 16:10 | Daily Secu reports; explicitly states initial access path, exploited vulnerability and ransomware involvement are all undisclosed | Daily Secu |
| 2026-11-26 17:17 | `www.danawa.com` 302-redirects to `construction.danawa.com`; both serve the notice image (`danawa_pm_20261126_2.jpg`). No recovery notice | Direct check |

> **No causal link has been established.** The press noted that the incident came one day after the ChatGPT integration announcement, but there is no evidence the integration was the entry point. "The AI integration got them hacked" is speculation, not a confirmed fact.

## 2. Confirmed facts

- **Down since 02:00**: the notice's "outage period 2026-11-26 (Thu) 02:00 ~" matches reporting from multiple outlets.
- **Stated cause is a suspected external intrusion**: the notice says the company "identified a security incident suspected to be an external intrusion and has suspended service to protect user information and services." It does not declare a confirmed breach.
- **Cause, scope and personal data exposure are under investigation.**
- **Authorities notified; an external security firm is participating** in the investigation.
- **Restoration will be staged**, server by server, as safety is verified; the schedule will be posted on the notice page.
- **Two user recommendations**: change the password if it is reused on other services; beware of calls, texts and emails impersonating Danawa.
- **Anti-phishing line in the notice**: "Danawa does not ask for your password or payment details by phone or text."
- **Scale reference**: about 7.23 million mobile MAU as of 2022 (company figure). A multi-hour outage also affects merchants and affiliate shopping malls.

## 3. Not yet confirmed (as of 17:00 KST, 2026-11-26)

| Item | Status |
| --- | --- |
| Initial access path | Undisclosed |
| Exploited vulnerability / attack method | Undisclosed |
| Ransomware involvement | Unconfirmed (per Daily Secu) |
| Member personal data or credentials leaked | Under investigation |
| Leak size (records, data types) | Unknown |
| Impact on affiliates / shared infrastructure (e.g. Enuri) | Flagged as needing review; no official statement |
| Restoration time | Not announced |

These items will change as notices are updated. In internal reports and customer communications, **leave them as "undisclosed."** "Danawa was hacked and personal data was stolen" is not, at this point, a confirmed statement.

## 4. What the Connectwave notice says

The notice is titled "Notice: Danawa service suspension" and signed "(주)커넥트웨이브 임직원 일동" (all Connectwave staff). In five points:

1. A security incident suspected to be an external intrusion was identified; service is suspended to protect user information and services.
2. Cause, scope and whether personal data was exposed are being investigated.
3. The relevant authorities have been notified, and an external security firm will join the investigation.
4. If a leak is confirmed, customers will be notified without delay under applicable law, individually where required.
5. Service will resume server by server as safety is verified; the schedule will be posted on the notice page.

Contact channels are the Danawa customer center (1688-2470) and `cs@cowave.kr`.

> The notice is published **only as a single image**, which makes it hard to search or quote. Record the capture time (17:07, 2026-11-26) and the image file name (`danawa_pm_20261126_2.jpg`, the afternoon revision).

## 5. What practitioners should take from this

1. **A "maintenance" notice that turns into an "incident" notice.** ZDNet reported that the maintenance wording was replaced by the intrusion notice. That means the first notice went out before the company had characterised the event — and the reporting clocks were already running.
2. **Two statutory clocks run at once.** Under Korea's Information and Communications Network Act, an intrusion must be reported within **24 hours** of detection; under the Personal Information Protection Act, a leak affecting **1,000 or more** people must be reported to the PIPC or KISA within **72 hours** (as summarised by ZDNet). Without a recorded detection time, both clocks are easily missed.
3. **Commerce platforms have a wide external surface.** Product and member databases, affiliate malls, merchant integrations — and now external AI integrations (ChatGPT, Claude). Each integration added is another place where **authentication, session and database boundaries** can loosen.
4. **An outage is not proof of a breach.** But a total shutdown plus external forensics looks like "isolate, then investigate," and the user and merchant communications have to be ready first.

## 6. Checklist for users

- Check whether your Danawa password is reused on other sites or work accounts; if so, change it now (Connectwave's advice).
- Do not click links in texts, calls or emails offering "Danawa compensation", refunds, account checks or identity verification. Danawa says it never asks for passwords or payment details by phone or text.
- If a password-reset email arrives for your Danawa address, go to Danawa directly rather than through the link, even though no leak is confirmed yet.
- Compare the shipping address and phone number stored at Danawa against recent delivery-scam and smishing messages.
- If a card is saved at Danawa, enable transaction alerts and review statements.

## 7. Checklist for service operators (DevSecOps)

### When extending external AI or commerce API integrations

- **Split credentials by purpose.** A token used for an AI integration should be **read-only on the product catalogue** and must not reach member, order or payment data.
- **Do not pass user sessions through.** Any design where an external widget or agent reuses a logged-in user's session cookie turns one integration into an account-takeover path. Use a separate service token for server-to-server calls.
- **Treat bulk reads as anomalous behaviour.** Price comparison and product scraping are indistinguishable from abuse unless you separate collection traffic from user traffic and enforce per-account and per-IP limits.
- **Put rate limits, WAF rules and request-schema validation on the integration endpoints.** New integrations usually open new hosts and paths, outside existing protections.
- **Predefine the rotation order for affiliate and merchant API keys.** Deciding at incident time which key to revoke first takes down healthy partners.

### Incident readiness

- **Record the moment of detection** — it starts the 24-hour and 72-hour clocks.
- **Have a "maintenance → incident" notice template.** As here, users judge by the first notice; keep the earlier one visible as history rather than deleting it.
- **Update status page, customer center and merchant channels in one step.**
- **Document the criteria for calling something a personal-data leak** (data types, encryption status, scale). Wavering mid-investigation is how reporting deadlines are missed.

## Sources

- Connectwave notice — "Notice: Danawa service suspension" (2026-11-26, outage from 02:00): https://construction.danawa.com/ — notice image `danawa_pm_20261126_2.jpg`, checked 17:17 on 2026-11-26 (`www.danawa.com` 302-redirects here)
- Electronic Times — [Exclusive] Danawa suspends service after security incident; "checking whether personal data leaked" (2026-11-26 14:56): https://www.etnews.com/20261126000392
- ZDNet Korea — Danawa suspends service over suspected external intrusion (2026-11-26 15:39, updated 16:12): https://zdnet.co.kr/view/?no=20261126153610
- Daily Secu — Danawa down after hacking incident; focus on whether member data leaked (2026-11-26 16:10): https://www.dailysecu.com/news/articleView.html?idxno=209761

Verification point: 17:00 KST, 2026-11-26. Cause, leak scope and recovery time will change as notices are updated; check the Connectwave notice and the latest reports before quoting.
