# Claude CVP + Mythos — how a security team uses a guardrail-relaxed model

[한국어](README.md) | [English](README_en.md)

Defending against AI attacks with AI is the realistic option. Anthropic's **Cyber Verification Program (CVP)** approves defense-focused security teams and DevSecOps practitioners to use Mythos with its security-related guardrails relaxed.

## Tiers

| Tier | Audience | Requirements |
| --- | --- | --- |
| Defense Access | General security teams, DevSecOps | MFA + 7-day key rotation; approval within days |
| Red Team | Penetration testing and vulnerability research | Separate review |

## Before you apply

- **Claude.ai (web chat) and Claude Platform (API, AWS, GCP) are separate organizations.** Approval does not carry over, so apply **from the account you will actually use**.
- **Static API keys are banned from 2026-12-15.** Prepare key rotation and workload identity migration in advance.
- Guardrails are relaxed in Mythos 5.1 / 5.2, but the allowed scope follows the approved tier and purpose.

## Where it helps in practice

- **Source analysis**: find and reproduce an authentication-logic flaw in Node.js that existing SAST missed, then patch it
- **Log analysis**: attach the judgment engine to centralized raw logs to filter anomalous calls
- **Reproduction**: verify vulnerability candidates with real requests to cut false positives

> A human must reproduce and verify whatever the model finds. Never ship an automatic patch without review.

## Preparation

- [ ] Decide which organization you will use (Claude.ai or Platform)
- [ ] Enable MFA and establish a 7-day key rotation procedure
- [ ] Plan the move from static API keys to short-lived credentials (before 12/15)
- [ ] Confirm the data-export policy for the code and logs you will analyze
- [ ] Document result verification and deployment approval

## References

- Anthropic CVP guide: https://support.claude.com/en/articles/14604842-cyber-verification-program
- Anthropic — Cyber Verification Program: https://www.anthropic.com/news/cyber-verification-program
- Anthropic — Mythos: https://www.anthropic.com/claude/mythos

Verified as of 2026-11-26. Program terms and dates may change.
