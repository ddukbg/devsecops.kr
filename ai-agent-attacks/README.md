# AI 에이전트가 주도한 침해 — EU 집행위 · 국내 대학 · 금융 · 외교

[한국어](README.md) | [English](README_en.md)

2026년 10~11월, 사람이 아니라 **AI 에이전트가 정찰·침투·웹 변조를 자동화한 사고**가 국내외에서 확인됐습니다. 공격 도구(ARTEX 등)를 AI 서비스에 연결해 스캔·익스플로잇·보고를 자동화하는 방식입니다.

## 확인된 사례

| 대상 | 시점 | 내용 |
| --- | --- | --- |
| EU 집행위 | 11/23 | 'EU 아카데미' 서비스 중단, 이름·이메일 유출 첫 확인. 중국계 AI 침투도구(ARTEX 등) 의심 |
| 국내 대학 20여 곳 | 11월 | S2W 분석 — 연구행정(rERP)·회계(UNIVais) 연쇄 침투·웹 변조. 유출 파일에 "허가된 CTF" 위장 지시, AI 작업 ID·예산 소진 로그까지 포착 |
| 국내 금융권 16곳+ | 10월 | 10만여 건 유출 사고에 동일 계열 AI 에이전트 악용 정황 (Microsoft) |
| 국내 외교·싱크탱크 | 11월 | CrowdStrike — 한국 관련 다수 표적, 일부 침투 성공 확인 |

- Microsoft는 **Storm-0940**이 ARTEX 계열 도구로 ConnectWise 공급망을 노린 캠페인을 분석했습니다.
- CrowdStrike는 **Vapor Panda**가 ARTEX로 글로벌 캠페인을 확장했다고 보고했습니다.
- S2W는 국내 대학 침해의 **KimJEN** 보고서를 공개했습니다.

## 공격이 빠른 이유

- 정찰·취약점 스캔·익스플로잇 시도·결과 정리를 에이전트가 병렬로 수행합니다.
- 사람이 눈치채기 전에 **관리자 페이지·테스트 페이지·SQL 실행 페이지** 같은 외부 노출 자산을 먼저 찾습니다.
- 웹 변조와 데이터 수집을 동시에 하고, 작업 ID·예산 로그를 남겨 다음 캠페인에 재사용합니다.

## DevSecOps 3대 점검

1. **외부 노출 관리자·테스트·SQL 실행 페이지 차단** — 인터넷에서 접근 가능한 관리 콘솔·스테이징·phpMyAdmin류를 먼저 인벤토리화
2. **배포 인증키·OAuth 토큰 즉시 로테이션** — CI/CD, 그룹웨어, 대학 행정 시스템의 장기 토큰
3. **비정상 대량 스캔·로그인 실패 Rate Limit** — IP 단위를 넘어 사용자·토큰 단위 카디널리티 제한

### 추가 탐지 포인트

- 웹 루트에 남은 `"authorized CTF"` 같은 위장 문구, 비정상 작업 ID·스크립트
- 짧은 시간에 여러 자산을 순회한 세션, 실패 후 즉시 성공한 로그인
- 외부로 나가는 대량 업로드(유출)와 웹 변조(무결성 변경) 알람

## 출처

- Microsoft — Storm-0940 uses ARTEX in ConnectWise supply chain compromise: https://www.microsoft.com/en-us/security/blog/2026/10/21/storm-0940-uses-artex-agentic-ai-connectwise-supply-chain-compromise/
- CrowdStrike — Vapor Panda uses ARTEX to scale global campaign: https://www.crowdstrike.com/en-us/blog/vapor-panda-uses-artex-to-scale-global-campaign/
- S2W — KimJEN 보고서: https://s2w.inc/ko/resources/1168
- Euronews — EU Commission cyberattack: https://www.euronews.com/2026/11/23/exclusive-china-backed-hackers-suspected-behind-ongoing-eu-commission-cyberattack

확인 기준일: 2026-11-26. 수사 중 사안은 내용이 변경될 수 있습니다.
