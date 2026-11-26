# Responding to a chain of cloud secret exposures — Rackspace Spot · Radware · Azure APIM · Argo CD

[한국어](README.md) | [English](README_en.md)

Within two weeks in November 2026, secret and key exposures were confirmed at a cloud platform, a WAF, an API gateway, and a CI/CD tool. The lesson is the same in every case.

> Blocking the intrusion path does not revoke the keys that already leaked.
> Issue the new key at the issuer (IAM, Entra, each console), then delete the old one.

## At a glance

| Incident | What was confirmed | Operational impact |
| --- | --- | --- |
| Rackspace Spot (11/17) | Stolen credentials used to deploy unauthorized workloads in customer clusters and access Kubernetes Secrets | Full cluster secret rotation; service shutdown on 12/08 |
| Radware Cloud WAF | Customer cloud access keys exposed (for S3/Blob log access) | Rotate log-bucket keys |
| Azure API Management Classic | Flaw exploited to steal secrets (Microsoft warning) | Review credentials issued by APIM |
| Argo CD | GHSA-q4f6-wc8m-r246 | Review deployment pipeline secrets |

## 1. Rackspace Spot — what happened

- Between **00:20 and 22:00 UTC on 2026-11-17**, an attacker used compromised credentials to deploy unauthorized workloads in customer clusters and **access Kubernetes Secrets**.
- Rackspace announced that the Spot platform closes permanently at **17:00 CST on 2026-12-08**. Workload migration and key rotation have to happen together.

### What Spot users should do now

1. **Revoke and reissue** Spot API tokens
2. Issue and distribute a new **kubeconfig** (discard the old one)
3. **Rotate every secret** in the cluster — database passwords, cloud keys, OIDC client secrets, third-party API keys
4. Retroactively review database audit logs, Git access logs, and cloud audit logs **since 11/17**

### IoC checks

```bash
# Look for pods by suspicious name prefixes
kubectl get pods -A | grep -E '^(i1|glm-|probe)'
```

- Suspicious IPs: `23.224.79.106`, range `23.224.0.0/15`
- Review S3 and Azure Blob access (`GetObject`, `ListBucket`) in CloudTrail and activity logs **since 11/16**. Start with calls that do not match deployment times.

## 2. Key rotation order

Get the order wrong and deployments break; then rollback pressure makes you revive the old key.

1. **Issue a new key at the issuer** — AWS IAM, Entra ID, each SaaS console
2. Deploy and verify the new key
3. **Deactivate, then delete** the old key
4. Check the last-used time of the old key in the logs (evidence of post-leak use)

> Disabling a leaked key "for now" is not rotation. Finish by deleting it.

## 3. Shared checklist

- [ ] No long-lived credentials in repositories, CI variables, or image layers (`git log -p`, CI secret inventory)
- [ ] Cloud keys replaced by workload identity (OIDC) or instance roles where possible
- [ ] Secret manager access logs reviewed for unusual principals and hours
- [ ] Outbound credential scope minimized for WAF, APIM, and CI/CD tools
- [ ] Owner and rotation procedure documented per issuer (so nobody has to ask during an incident)

## References

- BleepingComputer — Rackspace shuts down Spot cloud platform after security breach: https://www.bleepingcomputer.com/news/security/rackspace-shuts-down-spot-cloud-platform-after-security-breach/
- BleepingComputer — Radware discloses breach exposing customer cloud access keys: https://www.bleepingcomputer.com/news/security/radware-discloses-breach-exposing-customer-cloud-access-keys/
- CSO Online — Azure API Management flaw used to steal secrets: https://www.csoonline.com/article/4252513/attackers-exploited-an-azure-api-management-flaw-to-steal-secrets-microsoft-warns.html
- Argo CD advisory GHSA-q4f6-wc8m-r246: https://github.com/argoproj/argo-cd/security/advisories/GHSA-q4f6-wc8m-r246

Verified as of 2026-11-26. Shutdown and advisory details may change; check the vendor notices as well.
