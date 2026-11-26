# AI 에이전트 게이트웨이 — Google Workspace MCP/CLI 의무화와 AWS ELB for Envoy GA

[한국어](README.md) | [English](README_en.md)

2026년 11월 넷째 주에 같은 방향의 발표가 두 개 나왔습니다. Google은 **2027년 2월 1일부터 AI 에이전트가 Workspace REST API를 직접 호출하지 못하게** 하고 MCP 서버·CLI만 남깁니다. AWS는 **ELB for Envoy**를 GA로 열어 Envoy 프록시의 패치·업그레이드·용량을 관리형으로 넘겼습니다. 하나는 회사 데이터로 들어오는 문, 다른 하나는 트래픽이 나가는 문입니다. 두 발표의 공통점은 **"검사와 패치를 우리가 관리하는 단일 관문으로 모은다"** 입니다.

이 폴더는 두 발표의 **실제 숫자·날짜·제약**과, 사내 코드와 클러스터에서 지금 확인할 항목을 정리합니다. 확인 기준일은 **2026-11-27**입니다.

## 한눈에

| 항목 | Google Workspace | AWS ELB for Envoy |
| --- | --- | --- |
| 발표 | 2026-11-24 Workspace 블로그 · Google Cloud 블로그 | 2026-11-25 What's New |
| 무엇을 관리 | 에이전트 접속 경로(MCP 서버·CLI) | 프록시 fleet(전용 EC2 + Nitro 격리) |
| 강제 시점 | **2027-02-01** 기술적 강제(Workspace AI Tools Addendum) | GA, 도입은 선택 |
| 기본 한도 | MCP Standard **5,000건/일/프로젝트/제품** | 프록시 **25개/리전**, 설정 **128KB** |
| 비용 | Scaled Tier **2027-04-01**부터 과금 | 프록시 시간 + LCU, 데이터 전송 별도 |
| 리전 | 글로벌 SaaS | **14개 리전 — 서울 없음**(도쿄·싱가포르가 최근접) |
| 우리 몫 | OAuth 클라이언트 분리, DLP·라벨 정책, 승인 규칙 | bootstrap YAML 정확성, 튜닝, 확장 제약 회피 |
| 점검 | [check_agent_gateway_usage.sh](check_agent_gateway_usage.sh) | [agent-registry-elb-checklist.md](agent-registry-elb-checklist.md) |

## 1. Google — REST 직결의 끝, MCP가 유일한 문

### 1.1 무엇이 바뀌나

Workspace MCP 서버와 `Workspace CLI`가 **정식 출시(GA)** 됐습니다. MCP 서버는 Gmail, Drive, Docs, Sheets, Slides, Calendar, Chat, Tasks 8개 서비스를 열고(Keep은 예정), CLI는 로컬·데스크톱 에이전트용입니다. 같은 발표에 **Workspace AI Tools Addendum**이 함께 나왔고, 이 문서가 AI 에이전트의 접속 경로를 못 박습니다.

- AI 에이전트가 Workspace 데이터에 접근하려면 **Google MCP 서버 또는 CLI**를 써야 합니다.
- **2027-02-01**부터 기술적으로 강제됩니다(Addendum 발효 + MCP 요구 집행).
- 강제 이후 **REST API를 직접 호출하는 AI 도구는 티어 선택과 무관하게 Standard Tier 쿼터**로 제한됩니다.
- MCP 서버는 **에이전트가 아닌 OAuth 클라이언트를 거부**하고, 프롬프트·응답 검사는 **Model Armor**와 연동됩니다.

### 1.2 숫자와 날짜

| 날짜 | 내용 |
| --- | --- |
| 2026-05-01 | Gmail·Calendar·Drive API 기본 쿼터 문서화(신규 프로젝트 적용, 기존 프로젝트는 유지) |
| 2026-11-24 | Standard/Scaled 티어 공식 출시 · MCP 서버·CLI GA · 쿼터 대시보드 제공 |
| 2027-02-01 | Addendum 발효, MCP 요구 집행 시작 |
| 2027-04-01 | Scaled Tier 과금 시작, 전 프로젝트 표준 한도 집행 |
| 최소 2027-12까지 | Google Cloud Support 고객의 Workspace API 지원 변동 수수료 계산에서 제외 |

- **Standard Tier**: MCP 서버 기준 **5,000 요청/일/프로젝트/제품**(분당 한도 별도). 무료, 결제 계정 불필요. MCP 도구는 내부적으로 여러 API를 호출하므로 **도구 1회 호출이 여러 요청으로 계산**될 수 있습니다.
- **Scaled Tier**: MCP 쿼터 증액은 이 티어뿐입니다. 프로젝트 단위로만 선택할 수 있고 결제 계정 연결이 필요합니다. Light/Medium/Plus/Premium 4개 버킷으로 가격이 나뉘며, Gmail은 Light·Medium·Premium, Drive는 4개 전부, Calendar는 Plus만 씁니다.
- **내부용 예외(internal-use exception)**: REST API 쿼터는 올릴 수 있지만 **MCP 서버 쿼터는 이 예외로 증액할 수 없습니다.**
- Google은 "**활성 Workspace 개발자의 1% 미만**이 Standard Tier를 넘어설 것"으로 추정합니다. 반대로 말하면 99%는 무료 한도로 충분하다는 뜻이고, 에이전트를 대량으로 돌리는 팀만 과금 대상이 됩니다.

> 과금 시점의 차이를 놓치기 쉽습니다. REST API는 **일일 무료 한도 뒤**에 과금되지만, Scaled Tier의 Gmail·Calendar·Drive **MCP 사용은 첫 요청부터** 과금됩니다. MCP로 옮기면 "무료"라고 단정하면 안 됩니다.

### 1.3 에이전트에게 요구되는 것

1. **전용 OAuth 클라이언트 ID** + 최소 권한 스코프(시간 제한 승인은 예정).
2. **매 요청 정책 검사** — 조직 권한, DLP 규칙, 분류 라벨을 호출마다 확인.
3. **사람 확인(HITL)** — 외부 메일 발송, Drive 공유 권한 변경, 대량 편집 전 사용자 확인.
4. **가시성·회수** — 관리 콘솔에서 조회·차단·회수, (예정) 사용자별 에이전트 활동 확인.
5. **데이터 규칙** — 영구 원본 저장·모델 학습 금지, Google Technical Information 30일 초과 보관 금지, 연결 해제 시 데이터 삭제, 스크래핑 금지.

### 1.4 실무 함정

- **기존 앱의 OAuth 클라이언트를 재사용하면 "이전"이 아닙니다.** MCP 서버가 비(非)에이전트 클라이언트를 거부하므로, 에이전트 전용 클라이언트를 따로 발급해야 합니다.
- **서비스 단위가 아니라 프로젝트 단위**로 쿼터가 붙습니다. 여러 팀이 한 프로젝트를 공유하면 5,000건/일이 함께 소모됩니다.
- Cloud **Agent Gateway**를 쓰는 경우 Agent Registry의 Agent Identity로 검증하고, IAM·default-deny 아웃바운드·Model Armor를 그 지점에서 겁니다. 사내 정책 엔진이 따로 있으면 Service Extensions로 연결합니다.

## 2. AWS — Envoy 프록시를 관리형으로

### 2.1 무엇이 바뀌나

ELB for Envoy는 Elastic Load Balancing의 **새 로드밸런서 타입**입니다. 사용자는 Envoy bootstrap YAML과 (선택) 설정 아카이브를 주고, 서비스가 프록시를 프로비저닝·오토스케일·패치합니다.

- **전용 EC2 인스턴스 + AWS Nitro 하드웨어 격리** — 로드밸런서마다 프록시가 분리되어 Envoy 0-day가 다른 워크로드로 번지지 않습니다. VPC 암호화 기본 적용, ALB와 같은 단일 테넌트 구조.
- **CVE 모니터링 + Envoy/OS 자동 패치**, 트래픽 저하 감지 시 **자동 롤백**.
- **버전 지원 2년** (오픈소스 프로젝트는 1년). EOL 접근 시 AWS Health Dashboard로 통지.
- 기존 **컨트롤 플레인(xDS)·설정·확장을 그대로** 사용. ACM 인증서, AWS WAF, 보안 그룹, CloudWatch 지표·로그 연동.
- Kubernetes는 **ELB for Envoy remote infrastructure provider**를 Envoy Gateway 옆에 설치하면 Gateway API 리소스를 고치지 않고 프록시만 옮길 수 있습니다.

### 2.2 숫자와 제약

| 항목 | 값 |
| --- | --- |
| GA 리전 | 14개 — 버지니아·오하이오·오레곤·아일랜드·프랑크푸르트·스톡홀름·스페인·시드니·홍콩·도쿄·싱가포르·뭄바이·말레이시아·태국 |
| 프록시/리전/계정 | 25 (조정 가능) |
| AZ/프록시 | 최소 2 (조정 불가) |
| 설정 파일 | 128KB (조정 불가) |
| 설정 아카이브 | 10MB 압축 / 50MB 해제, 항목 50개 |
| ACM 인증서/프록시 | 25 · 인증서당 프록시 100 |
| 연결 드레이닝 | **60초 고정** — 연속 업데이트는 최소 60초 간격 |
| 과금 | 프록시 시간 + LCU(분 단위), 데이터 전송·퍼블릭 IPv4 별도 |

지원하지 않는 것(설정 검증 단계에서 거부됩니다):

- **Lua**: `io`, `debug`, `package`, `ffi`, `jit` 라이브러리 없음. `load`, `require`, `dofile`, `collectgarbage` 등도 사용 불가. 스크립트는 소스 텍스트만(바이트코드 거부).
- **Wasm**: V8 런타임만. 다른 런타임을 지정하면 거부.
- **액세스 로그**: file·stderr·stdout 로거 미지원 → OpenTelemetry, HTTP/gRPC, Fluentd 로거를 사용.
- **Envoy 동적 모듈**, **CLI 플래그**, **네트워크 네임스페이스 필드** 미지원. admin 인터페이스는 기본 비노출(사용 시 별도 접근 제어 필요).

### 2.3 한국 팀이 먼저 볼 것

- **서울 리전(ap-northeast-2)이 GA 목록에 없습니다.** 국내 워크로드는 도쿄(ap-northeast-1)나 싱가포르(ap-southeast-1)를 쓰게 되므로 **왕복 지연(RTT)** 과 **데이터 레지던시**를 먼저 계산해야 합니다. 프록시가 VPC 안에 있어도 리전이 다르면 같은 VPC가 아닙니다.
- 프록시 25개/리전은 기본값입니다. self-managed Envoy를 100대 이상 굴리는 조직이 주 타깃이므로, 그보다 작으면 ALB/NLB가 여전히 정답입니다(AWS 문서도 표준 로드밸런싱은 ALB·NLB를 권합니다).
- **자동 패치가 "설정 검증"까지 대신하지는 않습니다.** bootstrap YAML이 틀리면 배포 단계에서 실패하고, 확장이 이미지에 없으면 `envoy --mode validate`에서 걸립니다.

## 3. 지금 확인할 것

1. **REST 직결 인벤토리** — AI 에이전트·커넥터·자동화가 Workspace REST를 직접 호출하는지. → `bash check_agent_gateway_usage.sh --dir .`
2. **OAuth 클라이언트 분리** — 에이전트 전용 client ID, 최소 권한 스코프, 승인 규칙.
3. **한도·비용** — Standard 5,000건/일 초과 예상 서비스가 있는지, Scaled Tier 전환·과금 시점(2027-04-01) 계산.
4. **프록시 현황** — self-managed Envoy 대수, CVE 패치 리드타임, Lua·Wasm 사용 여부, 서울 리전 요구사항. → [agent-registry-elb-checklist.md](agent-registry-elb-checklist.md)

## 4. 점검 스크립트

```bash
# 소스에서 Workspace REST 직접 호출 흔적과 MCP/CLI 사용을 읽기 전용으로 스캔
bash check_agent_gateway_usage.sh --dir .

# Kubernetes의 Envoy Gateway 구성과 GatewayClass도 함께 보기
bash check_agent_gateway_usage.sh --dir . --kube

# CSV로 저장, 위험 항목이 있으면 종료코드 1
bash check_agent_gateway_usage.sh --dir . --csv > agent_gateway_audit.csv
bash check_agent_gateway_usage.sh --dir . --strict
```

이 스크립트는 **읽기 전용**입니다. 파일을 쓰지 않고, 클러스터에는 `get`만 보냅니다. grep 결과는 "흔적"이며, 실제 OAuth 클라이언트가 에이전트 전용인지·쿼터 티어가 무엇인지는 Cloud 콘솔에서 확인해야 합니다.

## 5. 출처

- Google Workspace 블로그, "Built for trust and control: New AI agent protections and developer tools in Google Workspace" (2026-11-24) — https://workspace.google.com/blog/product-announcements/built-for-trust-and-control-new-ai-agent-protections-and-developer-tools-in-google-workspace
- Google Cloud 블로그, "Deploying agents safely in your enterprise" (2026-11-24) — https://cloud.google.com/blog/products/identity-security/deploying-agents-safely-in-your-enterprise
- Google Workspace AI Tools Addendum (2026-11-24 개정) — https://workspace.google.com/terms/ai-tools/
- Workspace API·MCP 사용 티어와 쿼터 — https://developers.google.com/workspace/guides/quota-usage-tiers
- MCP 서버 구성(간접 프롬프트 인젝션·Model Armor) — https://developers.google.com/workspace/guides/configure-mcp-servers
- Agent Registry MCP 사용법 — https://docs.cloud.google.com/agent-registry/use-agentregistry-mcp
- AWS What's New, "Elastic Load Balancing for Envoy is now generally available" (2026-11-25) — https://aws.amazon.com/about-aws/whats-new/2026/11/elastic-load-balancing-for-envoy-generally-available/
- ELB for Envoy 제품 페이지 — https://aws.amazon.com/elasticloadbalancing/elbproxy
- ELB for Envoy 문서(개요·쿼터·제약) — https://docs.aws.amazon.com/elasticloadbalancing/latest/elbproxy/what-is.html
- ELB for Envoy remote infrastructure provider — https://github.com/aws/elb-envoy-remote-infra-provider
- Help Net Security, "Google mandates MCP or CLI access for Workspace AI agents starting February 2027" (2026-11-26) — https://www.helpnetsecurity.com/2026/11/26/google-ai-agent-security-requirements/
- Infosecurity Magazine, "Google Requires AI Agents to Access Workspace Through Approved Methods" (2026-11-26) — https://www.infosecurity-magazine.com/news/google-cloud-ai-agents-workspace/

> 확인 기준일 이후 정책·쿼터·리전은 바뀔 수 있습니다. 도입 판단 전에는 위 원문의 최신 날짜를 다시 확인하세요.
