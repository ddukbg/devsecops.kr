# Six open-source AI agents for security teams — Red vs Blue

[한국어](README.md) | [English](README_en.md)

Open-source AI agents a security team can put to work in 2026. Archived projects are excluded; only tools under active development on Docker or MCP are listed.

## Red Team — validating the attack surface

| Tool | License | Scale | What it does |
| --- | --- | --- | --- |
| **Strix** | Apache-2.0 | 66.7K★ | Web/API vulnerability discovery → real PoC validation → code patch suggestions |
| **PentAGI** | MIT | 25.2K★ | Multi-agent autonomous penetration testing with full Docker isolation |
| **CyberStrike** | CLI | 13 agents | Runs immediately in the terminal with existing Claude/OpenAI keys; 120+ OWASP checks, automatic MITRE ATT&CK mapping report |

> PentAGI is listed because the well-known CAI was archived in 2026.08 and removed from this list.

## Blue / Purple Team — detection and triage automation

| Tool | License | What it does |
| --- | --- | --- |
| **Vigil** (DeepTempo) | Apache-2.0 | SIEM/EDR integration over MCP, local Ollama in your network, 13 SOC agents. Destructive actions such as host isolation wait for human approval |
| **SIEMTriage** | Claude Agent SDK | Automates the first 15 minutes of MS Sentinel/Defender XDR investigation; KQL hunting; evidence report from VirusTotal and GreyNoise |
| **Ares + DreadGOAD** | MIT | Seven Red agents vs four Blue agents sparring on the same infrastructure; finds detection-rule gaps from live logs |

## Adoption guardrails

- [ ] Run in an isolated network first; allowlist outbound internet
- [ ] Destructive actions (host isolation, account lockout, deletion) require a **human approval gate**
- [ ] Credentials used by agents for SIEM/cloud are read-only and short-lived
- [ ] Mask customer PII before it reaches prompts and logs
- [ ] When using a local LLM (Ollama, etc.), confirm models and prompts never leave the internal network
- [ ] Retain agent execution logs separately (audit and reproducibility)

## References

- Vigil (DeepTempo): https://github.com/Vigil-SOC/vigil

Verified as of 2026-11-26. Star counts and features change; check each repository's license and recent commits.
