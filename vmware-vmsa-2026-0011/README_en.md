# VMware VMSA-2026-0011 — vCenter authentication bypass and ESX I/O filter RCE

[한국어](README.md) | [English](README_en.md)

Broadcom patched 23 VMware vulnerabilities on 2026-11-24. Three are rated CVSS 9.8. They are **separate bugs** from last week's zero-day patch (123890), so even patched environments must check again.

## Vulnerabilities

| CVE | Target | Detail |
| --- | --- | --- |
| CVE-2026-123903 | vCenter `vmdir` | Authentication bypass with network access alone (CVSS 9.8) |
| CVE-2026-123910 | ESX I/O filter | Host code execution without guest privileges (CVSS 9.8) |
| CVE-2026-123911 | ESX I/O filter | Host code execution without guest privileges (CVSS 9.8) |

- As of 2026-11-24, **no public exploitation or PoC is reported**. Last week's `vmdir` bug, however, reached KEV within days.
- Mitigation is the same with ELM disabled. Dell VxRail and HPE customers must check the vendor build.

## Fixed builds by version

| Product / branch | Fixed version · build | Note |
| --- | --- | --- |
| vCenter 9.1.x | **9.1.2 (25946533)** | New patch required |
| vCenter 9.0.x | **9.0.2.0300 (25937208)** | New patch required |
| vCenter 8.0 / VCF 5 | **8.0 U3m (25934264)** | Already applied = OK |
| ESX 9.1.x | **ESXi-9.1.2.0-25946735** | Reboot required |
| ESX 8.0 | **ESXi80U3m-25926933** | Workaround KB463535 |
| ESX 9.0.x | 9.0.2.0200* (Pending) | Re-check the matrix |

## Four reasons not to relax after last week's patch

1. **SAFE** — if vCenter 8.0 U3m (25934264) is already applied, no further vCenter patch is needed
2. **TRAP** — vCenter 9.1.1.0200 and 9.0.2.0200 are still vulnerable → 9.1.2 / 9.0.2.0300 required
3. **MISS** — ESX hosts were not in last week's advisory → separate patch and reboot (no Live Patch, including vSAN Witness)
4. **EOL** — vCenter/ESX 7.0 is past general support (EoGS 2025-10-02) with no public patch → upgrade unless you have extended support

## Immediate actions

1. **Block the vCenter bypass** — deny the management interface (5480) and `vmdir` ports from general user VLANs and the internet; allow only Admin/Jump hosts
2. **PowerCLI inventory**

```powershell
# Query builds of connected vCenter/ESX hosts
$global:DefaultVIServer.Version
$global:DefaultVIServer.Build
```

3. **Plan ESX downtime** — no Live Patch, so migrate VMs and reboot in sequence (including vSAN Witness and Avi LB)

## References

- Broadcom — VMSA-2026-0011: https://support.broadcom.com/web/ecx/support-content-notification/-/external/content/SecurityAdvisories/0/39626
- Broadcom — VMSA-2026-0011 Q&A: https://brcm.tech/vmsa-2026-0011-qna

Verified as of 2026-11-26. Check build numbers and patch status against the vendor advisory.
