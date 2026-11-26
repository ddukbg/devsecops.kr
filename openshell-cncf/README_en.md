# OpenShell — kernel-level isolation for AI agents (CNCF Sandbox)

[한국어](README.md) | [English](README_en.md)

**OpenShell**, an open-source runtime released by NVIDIA with Red Hat, Docker, and Canonical, joined the CNCF Sandbox on 2026-11-10. The point is not prompt guardrails but **OS kernel-level isolation**: an agent can run a shell without reaching host files or processes.

## At a glance

| Item | Detail |
| --- | --- |
| Project | OpenShell (NVIDIA + Red Hat, Docker, Canonical) |
| Governance | CNCF Sandbox (2026-11-10) |
| Implementation | Rust, Apache-2.0 |
| Isolation | Linux Landlock + seccomp kernel-level sandbox |
| Repository | GitHub 21.9k★, release v0.1.9 |
| Install | `curl -LsSf https://raw.githubusercontent.com/ai-openshell/openshell/main/install.sh | sh` |

## Why it matters

AI coding agents now write and execute code. Container isolation alone makes it hard to stop an agent's shell from reaching mounted secrets, the home directory, or other processes. OpenShell enforces file, process, and network rules in the kernel for each agent execution unit.

## Limitations to know before adopting

- **CNCF Sandbox 0.1.x is experimental.** The CLI and policy schema may change.
- File and process rules are **fixed manually**. There is no automatic learning or minimization.
- It does not restrict **cloud or Kubernetes API permissions outside the sandbox**. IAM permissions the agent holds still apply.

So OpenShell is not a complete control: **IAM least privilege plus a human approval gate** are still required.

## Adoption order

1. Apply OpenShell to the agent runtime and review the file/process scope under the default policy
2. Replace cloud credentials used by the agent with **workload identity / short-lived tokens**
3. Put destructive actions (delete, deploy, permission change) behind a **human approval gate**
4. Manage policy files in Git and code-review allowed paths and domains per agent

## References

- CNCF — Welcoming OpenShell to the CNCF (2026-11-10): https://www.cncf.io/blog/2026/11/10/welcoming-openshell-to-the-cncf-open-governance-to-secure-agentic-ai/
- GitHub — ai-openshell/openshell: https://github.com/ai-openshell/openshell

Verified as of 2026-11-26. The 0.1.x API may change; check the repository release notes.
