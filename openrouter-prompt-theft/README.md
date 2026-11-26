# OpenRouter 프롬프트 탈취 사건 — ZDR은 첫 번째 홉만 지킨다

[한국어](README.md) | [English](README_en.md)

"데이터 미저장(ZDR)" 옵션을 켰는데도 AI 플랫폼과 AWS 키가 새는 사고가 확인됐습니다. **OpenRouter 자체가 해킹된 것은 아니고, 요청을 넘겨받는 업스트림 추론 제공자가 문제**였습니다.

## 무슨 일이 있었나

- 보안 기업 **Dragos**가 7~11일 사이 **약 20만 건**의 프롬프트에서 AWS 키·API 키를 수집해 AI 서비스로 흘려보낸 정황을 확인했습니다.
- 수시간 안에 **S3·Secrets Manager 접근**까지 이어진 사례가 있었습니다.
- OpenRouter는 **제공자 3곳 퇴출 + ZDR 엔드포인트 125개 자격 중단**을 발표했습니다.
- ZDR 플러그인은 **요청이 게이트웨이를 지나는 첫 홉까지만** 보장합니다. 이후 업스트림 제공자가 모델 실행 전 원문을 보관·열람하면 막지 못합니다.

## 공격 흐름

```
AI 에이전트 / 사내 앱  (Prompt + AWS KEY, ZDR: ON)
        │
        ▼
OpenRouter (게이트웨이)  ← 자체 침해 없음, ZDR 하더라도 전달
        │
        ▼
업스트림 추론 제공자 / 리셀러 (Hop 2+)  ← 모델 실행 전 원문 보관·열람
        │
        ▼
정상 라우팅 중… 업스트림 제공사로 프롬프트 전달
```

## 실무 체크리스트

1. **업스트림 제공자 직접 점검** — ZDR 정책이 공개돼 있는지, 재판매 리셀러를 거치는지 확인
2. **노출 기간 사용된 API 토큰 즉시 로테이션** — AWS S3/IAM/Secrets Manager, OpenAI·Anthropic 키 포함
3. **프롬프트 시크릿 스크러빙 + 카나리 토큰** — 요청 전 정규식 마스킹, Canarytoken으로 유출 조기 탐지
4. **로그에서 IoC 사냥** — `artex-agent`, `artex-judge-r121`

### 토큰 로테이션 순서

발급처에서 새 키 발급 → 배포·검증 → 구 키 비활성화 → 삭제. (자세한 순서는 [클라우드 시크릿 연쇄 노출 대응](../cloud-secrets-exposure/README.md))

## 근본 대책

- 모델 호출에 **장기 AWS 키를 프롬프트에 넣지 않습니다.** 도구 호출은 서버 측 단기 자격증명으로 중계합니다.
- 외부 LLM 게이트웨이를 쓸 때는 **데이터 처리 계약과 제공자 목록**을 확인하고, 민감 데이터는 사내 모델·전용 엔드포인트로 분리합니다.

## 출처

- OpenRouter — Data processing incidents on inference providers: https://openrouter.ai/blog/announcements/data-processing-incidents-on-inference-providers/
- The Hacker News — OpenRouter drops 3 providers (Dragos 분석): https://thehackernews.com/2026/11/openrouter-drops-3-providers-after.html

확인 기준일: 2026-11-26.
