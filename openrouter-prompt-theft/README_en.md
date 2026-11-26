# The OpenRouter prompt-theft incident — ZDR only protects the first hop

[한국어](README.md) | [English](README_en.md)

Even with "zero data retention" (ZDR) enabled, AI platform and AWS keys leaked. **OpenRouter itself was not breached; the upstream inference providers that receive the requests were the problem.**

## What happened

- Security firm **Dragos** found roughly **200,000 prompts** over 7–11 days that harvested AWS and API keys and sent them to AI services.
- In some cases, **S3 and Secrets Manager access** followed within hours.
- OpenRouter **dropped 3 providers and suspended credentials for 125 ZDR endpoints**.
- The ZDR plugin only guarantees the **first hop** through the gateway. If an upstream provider stores or inspects the plaintext before running the model, ZDR cannot stop it.

## Attack flow

```
AI agent / internal app   (Prompt + AWS KEY, ZDR: ON)
        │
        ▼
OpenRouter (gateway)      ← not breached; forwards even with ZDR
        │
        ▼
Upstream inference provider / reseller (Hop 2+)  ← stores or inspects plaintext before the model runs
        │
        ▼
Normal routing… prompt delivered to the upstream provider
```

## Practical checklist

1. **Audit upstream providers directly** — is the ZDR policy published, and does traffic pass through a reseller?
2. **Rotate every API token used during the exposure window** — AWS S3/IAM/Secrets Manager as well as OpenAI and Anthropic keys
3. **Scrub secrets from prompts + use canary tokens** — regex masking before the request, Canarytoken for early leak detection
4. **Hunt the logs for IoCs** — `artex-agent`, `artex-judge-r121`

### Key rotation order

Issue the new key at the issuer → deploy and verify → deactivate the old key → delete it. (See [Cloud secret exposures](../cloud-secrets-exposure/README_en.md) for the full order.)

## The real fix

- **Do not put long-lived AWS keys in prompts.** Relay tool calls through short-lived credentials on the server side.
- When using an external LLM gateway, check the **data processing terms and the provider list**, and keep sensitive data on internal models or dedicated endpoints.

## References

- OpenRouter — Data processing incidents on inference providers: https://openrouter.ai/blog/announcements/data-processing-incidents-on-inference-providers/
- The Hacker News — OpenRouter drops 3 providers (Dragos analysis): https://thehackernews.com/2026/11/openrouter-drops-3-providers-after.html

Verified as of 2026-11-26.
