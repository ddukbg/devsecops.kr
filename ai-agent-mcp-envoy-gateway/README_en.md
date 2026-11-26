# AI agent gateways — Google Workspace MCP/CLI mandate and AWS ELB for Envoy GA

[한국어](README.md) | [English](README_en.md)

Two announcements landed in the same week of November 2026 with the same direction. Google will stop AI agents from calling Workspace REST APIs directly **from February 1, 2027**, leaving the Workspace MCP servers and CLI as the front door. AWS made **ELB for Envoy** generally available, taking patching, upgrades and capacity for Envoy proxies off platform teams. One is the door into company data, the other is the door traffic leaves through. Both move **inspection and patching into a single gateway the vendor operates**.

This folder records the actual numbers, dates and constraints, plus what to check in your own code and cluster. Verified **2026-11-27**.

## At a glance

| Item | Google Workspace | AWS ELB for Envoy |
| --- | --- | --- |
| Announced | 2026-11-24 Workspace blog · Google Cloud blog | 2026-11-25 What's New |
| What is managed | Agent access path (MCP servers, CLI) | Proxy fleet (dedicated EC2, Nitro isolation) |
| Deadline | **2027-02-01** technical enforcement (Workspace AI Tools Addendum) | GA, opt-in |
| Default limit | MCP Standard **5,000 requests/day/project/product** | **25 proxies per Region**, **128KB** config |
| Cost | Scaled Tier billing from **2027-04-01** | Proxy hours + LCU, data transfer extra |
| Regions | Global SaaS | **14 Regions — no Seoul** (Tokyo and Singapore are nearest) |
| Your side | OAuth client separation, DLP/label policy, approval rules | Correct bootstrap YAML, tuning, extension limits |
| Checks | [check_agent_gateway_usage.sh](check_agent_gateway_usage.sh) | [agent-registry-elb-checklist.md](agent-registry-elb-checklist.md) |

## 1. Google — the end of direct REST, MCP as the only door

### 1.1 What changes

Workspace MCP servers and the Workspace CLI are **generally available**. The MCP servers cover Gmail, Drive, Docs, Sheets, Slides, Calendar, Chat and Tasks (Keep coming soon); the CLI targets local and desktop agents. The same announcement introduced the **Workspace AI Tools Addendum**, which fixes the access path for AI agents.

- An AI agent reaching Workspace data must use the **Google MCP server or the Workspace CLI**.
- Enforcement is technical from **2027-02-01**.
- After that, AI tools calling Workspace **REST APIs directly are limited to Standard Tier quotas regardless of the tier selected**.
- MCP servers **reject non-agent OAuth clients** and integrate with **Model Armor** for prompt and response screening.

### 1.2 Dates and numbers

| Date | Detail |
| --- | --- |
| 2026-05-01 | Baseline quotas documented for Gmail, Calendar and Drive APIs (new projects; existing projects kept prior quotas) |
| 2026-11-24 | Standard/Scaled tiers launch · MCP servers and CLI GA · quota dashboard |
| 2027-02-01 | Addendum takes effect, MCP requirement enforced |
| 2027-04-01 | Scaled Tier billing starts, standard limits enforced across projects |
| Until at least 2027-12 | Workspace APIs excluded from Cloud Support variable fee |

- **Standard Tier**: **5,000 requests per day, per project, per product** for MCP servers (per-minute limits still apply). Free, no billing account. One MCP tool call can consume several requests because it makes several API calls.
- **Scaled Tier**: the only way to raise MCP quotas. Chosen per project, requires a linked billing account, priced in Light/Medium/Plus/Premium buckets (Gmail uses Light, Medium, Premium; Drive uses all four; Calendar uses Plus).
- **Internal-use exception**: raises REST API quotas but **MCP server quotas are not eligible**.
- Google estimates **fewer than 1% of active Workspace developers** will need to move beyond Standard Tier.

> Watch the billing difference. REST APIs are billed after a daily no-charge allowance, but Scaled Tier **Gmail, Calendar and Drive MCP usage is billed from the first request**. Moving to MCP is not automatically free.

### 1.3 What an agent must do

1. **Dedicated OAuth client ID** with least-privilege scopes (time-limited approvals coming).
2. **Policy check on every request** — org permissions, DLP rules, classification labels.
3. **Human confirmation** before sending external mail, changing Drive sharing, or bulk edits.
4. **Visibility and revocation** in the admin console.
5. **Data rules** — no permanent raw storage or model training, Google Technical Information kept no more than 30 days, data deleted on disconnect, no scraping.

### 1.4 Practical traps

- **Reusing an existing app's OAuth client is not a migration.** MCP servers reject non-agent clients, so issue an agent-specific client.
- Quotas are **per project**, not per service. Teams sharing a project share the 5,000/day.
- With Google Cloud **Agent Gateway**, agents are verified against Agent Registry identities, IAM and default-deny outbound rules apply at the protocol layer, and requests are screened by Model Armor; Service Extensions connects your own policy engine.

## 2. AWS — managed Envoy proxies

### 2.1 What changes

ELB for Envoy is a **new load balancer type** in Elastic Load Balancing. You supply an Envoy bootstrap YAML (and an optional configuration archive); the service provisions, scales and patches the proxy.

- **Dedicated EC2 instances with AWS Nitro hardware isolation** per load balancer, VPC encryption by default, same single-tenant architecture as ALB.
- **CVE monitoring plus automatic Envoy and OS patching**, with **automatic rollback** if traffic degrades.
- **Two years of support per Envoy version** (open source supports one). Lifecycle notices arrive through AWS Health Dashboard.
- Bring existing **control planes (xDS), configuration and extensions**; ACM, AWS WAF, security groups, CloudWatch metrics and logs are integrated.
- On Kubernetes, the **ELB for Envoy remote infrastructure provider** moves proxies behind Envoy Gateway without rewriting Gateway API resources.

### 2.2 Numbers and limits

| Item | Value |
| --- | --- |
| GA Regions | 14 — N. Virginia, Ohio, Oregon, Ireland, Frankfurt, Stockholm, Spain, Sydney, Hong Kong, Tokyo, Singapore, Mumbai, Malaysia, Thailand |
| Proxies per Region per account | 25 (adjustable) |
| AZs per proxy | At least 2 (not adjustable) |
| Configuration file | 128KB (not adjustable) |
| Configuration archive | 10MB compressed / 50MB uncompressed, 50 entries |
| ACM certificates per proxy | 25 · 100 proxies per certificate |
| Connection draining | **fixed at 60 seconds** — space updates at least that far apart |
| Pricing | Proxy hours + LCU per minute; data transfer and public IPv4 billed separately |

Not supported (rejected at validation):

- **Lua**: no `io`, `debug`, `package`, `ffi`, `jit`; no `load`, `require`, `dofile`, `collectgarbage`; source text only, bytecode rejected.
- **Wasm**: V8 runtime only.
- **Access loggers**: file, stderr and stdout loggers are unsupported → use OpenTelemetry, HTTP/gRPC or Fluentd.
- **Dynamic modules**, **Envoy CLI flags**, **network namespace fields**. The admin interface is not exposed by default.

### 2.3 For teams in Korea

- **Seoul (ap-northeast-2) is not in the GA list.** Korean workloads would use Tokyo or Singapore, so calculate **round-trip latency** and **data residency** first. A proxy inside "a VPC" in another Region is not your VPC.
- 25 proxies per Region is a default, and the target is organizations running 100+ self-managed proxies. Below that, ALB or NLB remains the right answer, as AWS's own documentation says.
- **Automatic patching does not validate your configuration.** A wrong bootstrap fails at deploy time, and a missing extension fails at `envoy --mode validate`.

## 3. What to check now

1. **REST call inventory** — does any agent, connector or automation call Workspace REST directly? → `bash check_agent_gateway_usage.sh --dir .`
2. **OAuth separation** — agent-specific client IDs, least-privilege scopes, approval rules.
3. **Limits and cost** — services likely to exceed 5,000/day, Scaled Tier switch and the 2027-04-01 billing date.
4. **Proxy posture** — self-managed Envoy count, CVE patch lead time, Lua/Wasm use, Seoul Region requirements. → [agent-registry-elb-checklist.md](agent-registry-elb-checklist.md)

## 4. Audit script

```bash
bash check_agent_gateway_usage.sh --dir .
bash check_agent_gateway_usage.sh --dir . --kube
bash check_agent_gateway_usage.sh --dir . --csv > agent_gateway_audit.csv
bash check_agent_gateway_usage.sh --dir . --strict
```

Read-only: it writes no files and sends only `get` calls to the cluster. grep hits are traces; whether an OAuth client is agent-specific and which tier a project is on must be confirmed in the Cloud console.

## 5. Sources

- Google Workspace blog, "Built for trust and control" (2026-11-24)
- Google Cloud blog, "Deploying agents safely in your enterprise" (2026-11-24)
- Workspace AI Tools Addendum (revised 2026-11-24)
- Workspace API and MCP usage tiers — https://developers.google.com/workspace/guides/quota-usage-tiers
- Configure the Workspace MCP servers — https://developers.google.com/workspace/guides/configure-mcp-servers
- Agent Registry MCP — https://docs.cloud.google.com/agent-registry/use-agentregistry-mcp
- AWS What's New, "Elastic Load Balancing for Envoy is now generally available" (2026-11-25)
- ELB for Envoy product page — https://aws.amazon.com/elasticloadbalancing/elbproxy
- ELB for Envoy docs (overview, quotas, limits) — https://docs.aws.amazon.com/elasticloadbalancing/latest/elbproxy/what-is.html
- ELB for Envoy remote infrastructure provider — https://github.com/aws/elb-envoy-remote-infra-provider
- Help Net Security (2026-11-26) · Infosecurity Magazine (2026-11-26) — independent coverage of the Google mandate

> Policies, quotas and Regions can change after the verification date. Re-check the primary sources before deciding.
