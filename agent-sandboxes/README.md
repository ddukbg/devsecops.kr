# AI 에이전트 샌드박스 — AWS Nitro Sandboxes vs Google Agent Compute Engine

[한국어](README.md) | [English](README_en.md)

에이전트가 코드를 짜고 셸을 실행하는 환경에서는 컨테이너 격리만으로 부족합니다. 프롬프트 인젝션 한 줄로 커널이 뚫리면 같은 노드의 다른 서비스와 IAM 키까지 함께 노출됩니다. 두 클라우드의 하드웨어 격리 모델을 실무 기준으로 비교했습니다.

## 비교표

| 항목 | AWS Nitro Sandboxes | Google Agent Compute Engine |
| --- | --- | --- |
| 기반 하이퍼바이저 | Nitro Hypervisor (Firecracker VMM) | Cloud Hypervisor + Titanium IPU 오프로드 |
| 적용 범위 | EKS 파드 · ECS 태스크 · EC2 직접 실행 (GA) | Gemini 에이전트 구동 (커스텀 Preview 예정) |
| 메모리 격리 | Confidential 모드 기본, 호스트·AWS도 열람 불가 | 게스트 커널 분리, 암호화 ID 기반 식별 |
| 비밀정보 주입 | NSM 암호화 증빙 통과 시 AWS KMS 복호화 | VM 밖 Egress 계층에서 단기 자격증명(Token) 주입 |
| 유휴 자원 최적화 | 부모 EC2 자원 분할, 세션 종료 시 즉시 파기 | CoW 메모리 공유 + LLM 대기 중 스냅샷 일시정지 |
| 스토리지·네트워크 | VPC CNI · EBS/EFS/S3 기존 연동 | 전용 Hyperdisk 영속화 + Agent Gateway 거버넌스 |
| 추가 비용 | Nitro 기반 EC2에서 추가 요금 없음 (GA) | Preview 단계 과금 모델 추후 공개 예정 |

## AWS Nitro Sandboxes

- Nitro 기반 EC2에서 추가 비용 없이 EKS·ECS 네이티브로 파드·태스크별 독립 VM을 제공합니다.
- **Confidential Mode(기본)**: 샌드박스 메모리와 CPU 레지스터를 부모 EC2에서 격리합니다.
- **NSM 증명 + KMS**: 실행 중 이미지 측정값(PCR)을 암호화 증명하고, KMS 키 정책에 그 측정값을 걸면 변조된 코드는 비밀을 복호화할 수 없습니다.

### 도입 전 제약

1. Nitro Enclaves 활성화 + Linux 호스트·Firecracker VMM 필요
2. Confidential ↔ Direct 모드는 **시작 시 결정**(실행 중 변경 불가)
3. 네트워크는 부모 인스턴스를 경유하므로 **TLS 종단 암호화 필수**

## Google Agent Compute Engine

- Titanium IPU가 네트워크·스토리지 경계를 하드웨어 수준에서 오프로드하고, Cloud Hypervisor가 독립 커널을 제공합니다.
- 에이전트가 LLM 응답을 기다리는(Thinking) 유휴 상태에 **VM을 스냅샷으로 일시정지**하고 CoW 메모리로 수십 개 세션을 밀집 구동합니다.
- 비밀정보를 VM 안에 두지 않고 **Egress 계층(Agent Gateway)에서만 단기 토큰을 주입**합니다. 작업 상태는 전용 Hyperdisk에 저장합니다.

## 운영 체크리스트

- [ ] 민감 에이전트는 **Confidential/Direct 모드 선택을 시작 시 확정**하고 기본값을 Confidential로
- [ ] KMS 키 정책에 **NSM PCR 측정값 조건**을 걸어 변조 코드의 복호화 차단
- [ ] 샌드박스 안에 `.env`·IAM 키를 두지 않고, 증명 또는 Egress 프록시에서 단기 토큰 주입
- [ ] **Egress deny-by-default** + 허용 도메인만 개방, 세션 종료 시 VM·디스크 즉시 파기
- [ ] 샌드박스 밖 클라우드 API 권한은 별도 IAM 최소권한으로 제한

### KMS 키 정책 예시

[`kms_nsm_pcr_policy.json`](kms_nsm_pcr_policy.json) — PCR 측정값 조건을 거는 키 정책 템플릿입니다. `<...>` 값을 실제 측정값으로 바꿔 사용하세요.

```bash
# EKS/EC2 Nitro Sandbox (Confidential Mode) 실행 예
aws ec2 run-instances --enclave-options Enabled=true \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=sandbox,Value=nitro}]'
```

## 출처

- AWS — Nitro Sandboxes: hardware isolation for every EKS pod, ECS task and EC2 workload: https://aws.amazon.com/blogs/compute/nitro-sandboxes-hardware-isolation-for-every-eks-pod-ecs-task-and-ec2-workload/
- AWS — Amazon EC2 Nitro Sandboxes 문서: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nitro-sandboxes.html
- Google — Agent Compute Engine and expanded agent governance: https://cloud.google.com/blog/topics/ai-infrastructure/introducing-agent-compute-engine-and-expanded-agent-governance

확인 기준일: 2026-11-26. Preview 기능과 과금은 변경될 수 있습니다.
