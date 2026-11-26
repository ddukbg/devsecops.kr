# AWS Lambda 30-minute timeout — six traps before you raise it

[한국어](README.md) | [English](README_en.md)

For the first time since 2018, the AWS Lambda timeout for on-demand event functions has doubled from **15 minutes to 30 minutes (1,800 seconds)**. The per-GB-second price and billing model are unchanged. Raising `--timeout 1800` alone, however, causes failures in concurrency, queues, and networking.

## Limits differ by form factor (not everything is 30 minutes)

| Form factor | Maximum | Note |
| --- | --- | --- |
| Event Functions (on-demand) | **30 min (1,800s)** | Sync / Async / ESM |
| Managed Instances (Sync) | 30 min (1,800s) | Async/ESM remain 90 min (5,400s) |
| Web Functions / MicroVMs | 15 min / 8 hours | Web stays at 15 min |
| Init phase | 10 sec | 15 min only for SnapStart/Managed |
| Durable Functions | 30 min per execution | Workflow lifetime up to 1 year |

### Still capped at 14 minutes (840s)

1. Amazon MQ (ActiveMQ, RabbitMQ)
2. Amazon DocumentDB
3. **Kafka ESMs created before 2026-11-19** — enable provisioned mode or recreate the ESM to get 30 minutes

## Six traps

1. **Double the concurrency** — 1 req/s × 30 min occupies 1,800 concurrent executions. Recalculate the limit from `RPS × average duration`.
2. **Caller timeouts** — if the front end (API Gateway at 29s, etc.) closes first, 30 minutes is useless. Raise SDK read/socket timeouts too.
3. **SQS visibility 6× rule** — fix the visibility timeout at **10,800s or more**. It is checked only when the mapping is created, so enforce it in CI/CD policy.
4. **NAT Gateway 350-second idle cutoff** — long runs need **TCP keep-alive**. JVM runtimes cache DNS, so set **TTL 5s** to follow endpoint changes.
5. **Stream partial failures** — for Kinesis/DynamoDB, monitor `IteratorAge` and enable `Partial Batch Failure`.
6. **Durable/exactly-once** — a failure at minute 22 re-bills from the start. Combine `Durable step()` checkpoints, and after three async timeouts send to a DLQ and apply Powertools idempotency keys.

## Configuration example

```bash
aws lambda update-function-configuration \
  --function-name my-fn \
  --timeout 1800
```

## Pre-deploy checklist

- [ ] Recalculate concurrency from `RPS × duration`; review reserved concurrency
- [ ] Raise caller (API GW, ALB, SDK) timeouts
- [ ] SQS visibility ≥ 10,800s, enforced by code policy
- [ ] NAT keep-alive and JVM DNS TTL 5s
- [ ] Stream `IteratorAge` alarms and partial batch failure handling
- [ ] Durable steps, idempotency keys, DLQ
- [ ] Confirm the 14-minute exceptions (MQ, DocumentDB, existing Kafka ESM)

## References

- AWS Compute Blog — 30-minute timeout for on-demand Lambda event functions: https://aws.amazon.com/blogs/compute/announcing-30-minute-timeout-for-on-demand-aws-lambda-event-functions/
- InfoQ — measured analysis: https://www.infoq.com/news/2026/11/aws-lambda-30-minute-timeout/
- DEV Community — Six checks before you change it: https://dev.to/damogallagher/lambdas-30-minute-timeout-six-checks-before-you-change-it-4b2e

Verified as of 2026-11-26.
