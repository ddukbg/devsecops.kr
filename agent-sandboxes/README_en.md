# AI agent sandboxes — AWS Nitro Sandboxes vs Google Agent Compute Engine

[한국어](README.md) | [English](README_en.md)

When agents write code and run shells, container isolation is not enough. One line of prompt injection that breaks the kernel exposes every other service on the node and its IAM keys. Here is a practical comparison of the two clouds' hardware isolation models.

## Comparison

| Dimension | AWS Nitro Sandboxes | Google Agent Compute Engine |
| --- | --- | --- |
| Hypervisor | Nitro Hypervisor (Firecracker VMM) | Cloud Hypervisor + Titanium IPU offload |
| Scope | EKS pods, ECS tasks, EC2 direct (GA) | Gemini agent workloads (custom Preview planned) |
| Memory isolation | Confidential mode by default; host and AWS cannot read | Guest kernel separation; encrypted ID-based identity |
| Secret injection | AWS KMS decrypt only after NSM encrypted attestation | Short-lived token injected at the Egress layer outside the VM |
| Idle optimization | Parent EC2 resources split; destroyed at session end | CoW memory sharing + snapshot pause while the LLM is thinking |
| Storage/network | VPC CNI, EBS/EFS/S3 native | Dedicated Hyperdisk persistence + Agent Gateway governance |
| Extra cost | No additional charge on Nitro-based EC2 (GA) | Preview pricing to be announced |

## AWS Nitro Sandboxes

- Delivers an independent VM per pod or task natively in EKS/ECS at no extra cost on Nitro-based EC2.
- **Confidential Mode (default)**: sandbox memory and CPU registers are isolated from the parent EC2 instance.
- **NSM attestation + KMS**: the running image measurement (PCR) is attested with encryption; if the KMS key policy requires that measurement, modified code cannot decrypt the secret.

### Constraints before adoption

1. Nitro Enclaves enabled + Linux host and Firecracker VMM required
2. Confidential ↔ Direct mode is **decided at start** (cannot change while running)
3. Networking passes through the parent instance, so **TLS end-to-end encryption is required**

## Google Agent Compute Engine

- The Titanium IPU offloads network and storage boundaries in hardware, and Cloud Hypervisor provides an independent kernel.
- While the agent waits for the LLM (Thinking), the VM is **paused as a snapshot**, and CoW memory packs dozens of sessions densely.
- Secrets are not placed inside the VM; **short-lived tokens are injected only at the Egress layer (Agent Gateway)**. Work state persists on dedicated Hyperdisk.

## Operational checklist

- [ ] Fix **Confidential/Direct mode at start** for sensitive agents, defaulting to Confidential
- [ ] Add **NSM PCR measurement conditions** to the KMS key policy to block decryption by modified code
- [ ] Keep `.env` and IAM keys out of the sandbox; inject short-lived tokens via attestation or an egress proxy
- [ ] **Egress deny-by-default** with allowed domains only; destroy VM and disk at session end
- [ ] Limit cloud API permissions outside the sandbox with separate IAM least privilege

### KMS key policy example

[`kms_nsm_pcr_policy.json`](kms_nsm_pcr_policy.json) — a key policy template that requires PCR measurements. Replace the `<...>` placeholders with your actual measurements.

```bash
# Run an EKS/EC2 Nitro Sandbox (Confidential Mode)
aws ec2 run-instances --enclave-options Enabled=true \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=sandbox,Value=nitro}]'
```

## References

- AWS — Nitro Sandboxes: hardware isolation for every EKS pod, ECS task and EC2 workload: https://aws.amazon.com/blogs/compute/nitro-sandboxes-hardware-isolation-for-every-eks-pod-ecs-task-and-ec2-workload/
- AWS — Amazon EC2 Nitro Sandboxes documentation: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nitro-sandboxes.html
- Google — Agent Compute Engine and expanded agent governance: https://cloud.google.com/blog/topics/ai-infrastructure/introducing-agent-compute-engine-and-expanded-agent-governance

Verified as of 2026-11-26. Preview features and pricing may change.
