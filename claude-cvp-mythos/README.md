# Claude CVP + Mythos — 보안팀이 가드레일 완화 모델을 쓰는 방법

[한국어](README.md) | [English](README_en.md)

AI 공격은 AI로 막는 것이 현실적입니다. Anthropic의 **Cyber Verification Program(CVP)** 은 방어 목적 보안팀·DevSecOps가 Mythos의 보안 관련 가드레일을 완화해 쓰도록 승인하는 프로그램입니다.

## 티어

| 티어 | 대상 | 조건 |
| --- | --- | --- |
| Defense Access | 일반 보안팀·DevSecOps | MFA + 7일 키 교체, 며칠 내 승인 |
| Red Team | 침투 테스트·취약점 연구 조직 | 별도 심사 |

## 신청 전 알아야 할 것

- **Claude.ai(웹 채팅)와 Claude Platform(API·AWS·GCP)은 별도 조직**입니다. 승인이 다른 조직으로 넘어가지 않으므로 **실제로 쓸 계정에서 신청**해야 합니다.
- **2026-12-15부터 정적 API 키가 전면 금지**됩니다. 키 교체 주기와 워크로드 아이덴티티 전환을 미리 준비하세요.
- Mythos 5.1 / 5.2에서 가드레일이 완화되지만, 허용 범위는 승인 티어와 사용 목적에 따릅니다.

## 실무에서 쓸 수 있는 지점

- **소스 분석**: 기존 SAST가 놓친 Node.js 인증 로직 결함을 소스만으로 찾아 재현·패치
- **로그 분석**: 중앙화한 원본 로그에 판단 엔진을 붙여 이상 호출 필터링
- **재현 검증**: 취약점 후보를 실제 요청으로 재현해 오탐을 줄임

> 모델이 찾은 결과는 반드시 사람이 재현·검증합니다. 자동 패치를 무검토로 배포하지 마세요.

## 준비물

- [ ] 사용할 조직(Claude.ai / Platform) 확정
- [ ] MFA 활성화, 7일 키 교체 절차 수립
- [ ] 정적 API 키 → 단기 자격증명 전환 계획 (12/15 전)
- [ ] 분석 대상 코드·로그의 반출 정책 확인
- [ ] 결과 검증·배포 승인 절차 문서화

## 출처

- Anthropic CVP 안내: https://support.claude.com/en/articles/14604842-cyber-verification-program
- Anthropic — Cyber Verification Program: https://www.anthropic.com/news/cyber-verification-program
- Anthropic — Mythos: https://www.anthropic.com/claude/mythos

확인 기준일: 2026-11-26. 프로그램 조건·일정은 변경될 수 있습니다.
