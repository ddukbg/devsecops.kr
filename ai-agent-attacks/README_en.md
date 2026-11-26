# AI-agent-driven intrusions — EU Commission, Korean universities, finance, diplomacy

[한국어](README.md) | [English](README_en.md)

In October and November 2026, incidents were confirmed in Korea and abroad in which **AI agents, not people, automated reconnaissance, intrusion, and website defacement**. Attack tooling such as ARTEX is connected to AI services to automate scanning, exploitation, and reporting.

## Confirmed cases

| Target | Date | Detail |
| --- | --- | --- |
| EU Commission | 11/23 | "EU Academy" service taken down; names and emails confirmed leaked. Chinese-origin AI intrusion tooling (ARTEX, etc.) suspected |
| ~20 Korean universities | November | S2W analysis — chained intrusion into research administration (rERP) and accounting (UNIVais) systems, website defacement. Leaked files contained disguised "authorized CTF" instructions and AI task IDs and budget-exhaustion logs |
| 16+ Korean financial companies | October | Signs of the same family of AI agents behind a breach of about 100,000 records (Microsoft) |
| Korean diplomatic and think-tank targets | November | CrowdStrike observed multiple Korea-related targets and confirmed some successful intrusions |

- Microsoft analyzed **Storm-0940** using ARTEX-family tooling against the ConnectWise supply chain.
- CrowdStrike reported **Vapor Panda** scaling a global campaign with ARTEX.
- S2W published the **KimJEN** report on the Korean university intrusions.

## Why it is fast

- Agents run reconnaissance, vulnerability scanning, exploitation attempts, and result write-ups in parallel.
- They find externally exposed assets first — **admin pages, test pages, SQL execution pages** — before anyone notices.
- They deface sites and collect data at the same time, and retain task IDs and budget logs for the next campaign.

## Three DevSecOps checks

1. **Block externally exposed admin, test, and SQL execution pages** — inventory internet-reachable consoles, staging sites, and phpMyAdmin-style tools first
2. **Rotate deployment keys and OAuth tokens immediately** — long-lived tokens in CI/CD, groupware, and university administration systems
3. **Rate-limit abnormal bulk scans and login failures** — cardinality limits per user/token, beyond per-IP limits

### Additional detection points

- Disguised strings such as `"authorized CTF"`, unusual task IDs, or scripts left in the web root
- Sessions traversing multiple assets in a short time; logins that fail repeatedly then succeed
- Large outbound uploads (exfiltration) and website integrity changes

## References

- Microsoft — Storm-0940 uses ARTEX in ConnectWise supply chain compromise: https://www.microsoft.com/en-us/security/blog/2026/10/21/storm-0940-uses-artex-agentic-ai-connectwise-supply-chain-compromise/
- CrowdStrike — Vapor Panda uses ARTEX to scale global campaign: https://www.crowdstrike.com/en-us/blog/vapor-panda-uses-artex-to-scale-global-campaign/
- S2W — KimJEN report: https://s2w.inc/ko/resources/1168
- Euronews — EU Commission cyberattack: https://www.euronews.com/2026/11/23/exclusive-china-backed-hackers-suspected-behind-ongoing-eu-commission-cyberattack

Verified as of 2026-11-26. Ongoing investigations may change the details.
