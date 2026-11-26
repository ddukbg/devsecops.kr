# AWS Lambda 30분 타임아웃 — 올리기 전 6가지 함정

[한국어](README.md) | [English](README_en.md)

AWS Lambda 온디맨드 Event Functions 타임아웃이 2018년 이후 8년 만에 **15분 → 30분(1,800초)** 으로 상향됐습니다. GB-초 단가와 과금 방식은 그대로입니다. 다만 `--timeout 1800`만 올리면 동시성·큐·네트워크에서 장애가 납니다.

## 폼팩터별 한도 (전부 30분이 아님)

| 실행 형태 | 최대 제한 | 비고 |
| --- | --- | --- |
| Event Functions (온디맨드) | **30분 (1,800s)** | Sync / Async / ESM 전 상용 |
| Managed Instances (Sync) | 30분 (1,800s) | Async·ESM은 90분(5,400s) |
| Web Functions / MicroVMs | 15분 / 8시간 | Web은 15분 그대로 |
| Init 초기화 단계 | 10초 | SnapStart·Managed만 15분 |
| Durable Functions | 실행 30분 | 전체 워크플로 수명은 최대 1년 |

### 여전히 14분(840초)으로 묶이는 예외

1. Amazon MQ (ActiveMQ·RabbitMQ)
2. Amazon DocumentDB
3. **2026-11-19 이전 생성된 기존 Kafka ESM** — 프로비저닝 모드로 켜거나 ESM을 새로 만들어야 30분 적용

## 6가지 함정

1. **동시성 2배** — 1 req/s × 30분 = 동시 실행 1,800개 점유. `RPS × 평균 실행시간`으로 동시성 한도를 다시 계산합니다.
2. **호출자 타임아웃** — API Gateway(29초) 등 앞단이 먼저 끊으면 30분은 무용지물. `SDK Read/Socket 타임아웃`도 함께 올립니다.
3. **SQS Visibility 6배 규칙** — Visibility Timeout을 **10,800초 이상**으로 고정. 매핑 생성 시에만 검사하므로 CI/CD 정책으로 사후 변경을 막습니다.
4. **NAT Gateway 350초 유휴 끊김** — 긴 실행에는 **TCP Keep-Alive** 필수. JVM은 DNS 캐시 고정 런타임이라 **TTL 5초** 설정으로 엔드포인트 변경에 대응합니다.
5. **스트림 부분 실패** — Kinesis/DynamoDB는 `IteratorAge` 모니터링 + `Partial Batch Failure` 필수.
6. **Durable/멱등성** — 22분쯤 실패하면 처음부터 재과금됩니다. `Durable step()` 체크포인트를 결합하고, 비동기 3회 타임아웃 시 DLQ로 보낸 뒤 Powertools 멱등키를 적용합니다.

## 설정 예

```bash
aws lambda update-function-configuration \
  --function-name my-fn \
  --timeout 1800
```

## 배포 전 체크리스트

- [ ] `RPS × 실행시간`으로 동시성 재계산, 예약 동시성 검토
- [ ] 호출자(API GW·ALB·SDK) 타임아웃 상향
- [ ] SQS Visibility ≥ 10,800초 + 코드 정책으로 강제
- [ ] NAT Keep-Alive, JVM DNS TTL 5초
- [ ] 스트림 `IteratorAge` 알람, 부분 배치 실패 처리
- [ ] Durable step·멱등키·DLQ 구성
- [ ] 14분 예외(MQ·DocumentDB·기존 Kafka ESM) 확인

## 출처

- AWS Compute Blog — 30-minute timeout for on-demand Lambda event functions: https://aws.amazon.com/blogs/compute/announcing-30-minute-timeout-for-on-demand-aws-lambda-event-functions/
- InfoQ — 실측 분석: https://www.infoq.com/news/2026/11/aws-lambda-30-minute-timeout/
- DEV Community — Six checks before you change it: https://dev.to/damogallagher/lambdas-30-minute-timeout-six-checks-before-you-change-it-4b2e

확인 기준일: 2026-11-26.
