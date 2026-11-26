# AI 에이전트 게이트웨이 점검 체크리스트 — Agent Registry · ELB for Envoy

카드뉴스 21편(2026-11-27) 기준. **읽기 전용 점검**이며, 판단 근거가 되는 값은 각 항목의 "증적" 칸에 적습니다.
원문: [README.md](README.md) · 자동 점검: [check_agent_gateway_usage.sh](check_agent_gateway_usage.sh)

## A. Google Workspace — 2027-02-01 전에 끝내야 하는 것

| # | 확인 항목 | 판정 기준 | 증적(콘솔·코드 경로) |
| --- | --- | --- | --- |
| A1 | AI 에이전트·커넥터·자동화가 Workspace REST를 직접 호출하는가 | `check_agent_gateway_usage.sh` 결과 0건이면 통과. 1건 이상이면 목록화 | |
| A2 | 호출 주체가 **에이전트 전용 OAuth 클라이언트**인가 | 기존 앱 클라이언트 재사용은 불가. MCP 서버가 비(非)에이전트 클라이언트를 거부 | |
| A3 | 스코프가 최소 권한인가 | `gmail.send`·`drive` 전체 범위가 업무상 필요한지 재확인 | |
| A4 | 대상 서비스 범위 | Gmail·Drive·Docs·Sheets·Slides·Calendar·Chat·Tasks 8종 중 실제 사용분만 이전 | |
| A5 | Standard Tier 5,000건/일/프로젝트/제품 초과 예상 서비스가 있는가 | 쿼터 대시보드의 프로젝트별 사용량으로 판단 | |
| A6 | 초과 시 Scaled Tier 전환 여부 | **내부용 예외로는 MCP 쿼터 증액 불가**. 결제 계정 연결 필요 | |
| A7 | 2027-04-01 과금 영향 | Gmail·Calendar·Drive MCP는 **첫 요청부터** 과금(무과금 한도 없음) | |
| A8 | 고위험 작업 승인 규칙 | 외부 메일 발송·Drive 공유 변경·대량 편집에 사용자 확인이 걸려 있는가 | |
| A9 | DLP·분류 라벨 정책 | MCP 경유 호출에 기존 DLP 규칙과 라벨이 그대로 적용되는가 | |
| A10 | 프롬프트 검사 | Model Armor 또는 자체 검사 사용 여부와 로그 보관 정책 | |
| A11 | 데이터 규칙(Addendum) | 원본 영구 저장·모델 학습 금지, Google Technical Information 30일 이내 파기, 연결 해제 시 삭제 | |
| A12 | Cloud Agent Gateway 사용 시 | Agent Registry의 Agent Identity로 검증, IAM·default-deny 아웃바운드, 사내 정책 엔진 연결 | |

> A7은 놓치기 쉬운 지점입니다. "MCP로 옮기면 무료"가 아니라 **MCP 대량 사용은 유료 티어**입니다. REST는 일일 무과금 한도 뒤에 과금됩니다.

## B. AWS ELB for Envoy — 도입 판단

| # | 확인 항목 | 판정 기준 | 증적 |
| --- | --- | --- | --- |
| B1 | self-managed Envoy 프록시 대수 | 100대 이상이면 관리형 이득이 큼. 소수면 ALB/NLB가 여전히 정답 | |
| B2 | 담당 팀이 Envoy·OS CVE 패치를 직접 하는가 | 패치 리드타임이 길수록 이득 | |
| B3 | 서울 리전 요구사항 | **GA 14개 리전에 서울 없음**. 도쿄·싱가포르 사용 시 RTT·데이터 레지던시 검토 | |
| B4 | 기존 컨트롤 플레인 | xDS로 붙는 사내 컨트롤 플레인을 그대로 쓸 수 있는가 | |
| B5 | Gateway API 사용 | Envoy Gateway + remote infrastructure provider로 리소스 수정 없이 이전 가능 | |
| B6 | 설정 크기 | bootstrap YAML 128KB, 아카이브 10MB(압축)/50MB(해제)·50개 이내인가 | |
| B7 | 확장 제약 | Lua에서 `io`·`debug`·`package`·`ffi`·`jit` 미사용, Wasm은 V8만 | |
| B8 | 로깅 | file·stderr·stdout 액세스 로거 미지원 → OTel/HTTP·gRPC/Fluentd로 전환 필요 | |
| B9 | 업데이트 절차 | 연결 드레이닝 60초 고정 → 연속 설정 변경 간격 | |
| B10 | 프록시 수량 | 25개/리전/계정(조정 가능), 프록시당 AZ 최소 2 | |
| B11 | 비용 | 프록시 시간 + LCU, 데이터 전송·퍼블릭 IPv4 별도. 기존 fleet 비용과 비교 | |
| B12 | 버전 수명 | 서비스가 버전당 2년 지원, EOL 통지는 AWS Health Dashboard | |

## C. 공통 — 운영 준비

- [ ] 인증서·도메인 정리: ACM 인증서/프록시 25개, 인증서당 프록시 100개 한도
- [ ] 관측성: CloudWatch 지표·로그, Envoy admin 인터페이스 접근 제어(기본 비노출)
- [ ] 롤백 계획: 자동 롤백이 동작하지 않는 경우(설정 오류) 수동 복구 절차
- [ ] 변경 공지: 2027-02-01·2027-04-01 일정을 사내 캘린더·런북에 등록

## D. 점검 명령

```bash
# 소스 스캔(읽기 전용)
bash check_agent_gateway_usage.sh --dir .

# 클러스터의 Envoy Gateway 구성까지
bash check_agent_gateway_usage.sh --dir . --kube

# 위험 항목이 있으면 종료코드 1
bash check_agent_gateway_usage.sh --dir . --strict
```
