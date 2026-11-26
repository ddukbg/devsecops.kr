# AWS 공식 로컬 에뮬레이터 `aws/aws-emulator` — CI에 쓰기 전 알아야 할 제약

[한국어](README.md) | [English](README_en.md)

AWS가 직접 공개한 무료 로컬 에뮬레이터입니다. Rust 단일 바이너리로 438개 API 모델(200+ 서비스)을 로컬에서 실행하고, CC0-1.0 라이선스라 계정·과금 없이 CI/CD에 넣을 수 있습니다. 다만 **로컬 테스트 통과가 운영 배포 안전을 뜻하지는 않습니다.**

## 한눈에

| 항목 | 내용 |
| --- | --- |
| 저장소 | https://github.com/aws/aws-emulator |
| 구현 | Rust 단일 바이너리 |
| 범위 | 438개 API 모델 / 200+ 서비스 |
| 엔드포인트 | `127.0.0.1:9297` |
| 라이선스 | CC0-1.0 |
| 공개 직후 | GitHub 9.9K★ |

## 실무 제약 4가지

1. **IAM 우회** — Permissions Boundary, Session Policy, 무권한 `sts:AssumeRole`이 통과할 수 있습니다. DevOps-Daily 실측 32개 IAM 케이스 중 27개만 실제 AWS와 일치했습니다.
2. **범위 한계** — KMS 키 정책, 크로스 계정, 멀티 리전 미지원(us-east-1 단일).
3. **코드 비격리** — Lambda 등 함수 코드가 호스트 사용자 권한으로 직접 실행됩니다. 신뢰할 수 없는 코드를 돌리지 마세요.
4. **텔레메트리 기본 ON** — 사내망·CI에서는 반드시 끕니다.

```bash
# 텔레메트리 비활성화
aws-emulator --telemetry off
# 또는 환경변수
export EMULATOR_TELEMETRY=off
```

## CI에 넣는 방법

- 에뮬레이터는 **단위·통합 테스트용**으로만 쓰고, IAM·KMS·크로스 계정 검증은 실제 AWS 임시 계정에서 합니다.
- 에뮬레이터 결과만으로 배포 승인하는 파이프라인은 만들지 않습니다.
- 네트워크는 `127.0.0.1` 바인딩을 유지하고 CI 러너 밖으로 노출하지 않습니다.

## 출처

- GitHub — aws/aws-emulator: https://github.com/aws/aws-emulator
- AWS — Emulator 보안 제약 문서: https://docs.aws.amazon.com/emulator/latest/userguide/security.html
- DevOps-Daily — 32건 IAM 권한 실측 비교: https://devops-daily.com/posts/aws-emulator-hands-on-test

확인 기준일: 2026-11-26. 에뮬레이터는 빠르게 바뀌므로 릴리스 노트를 확인하세요.
