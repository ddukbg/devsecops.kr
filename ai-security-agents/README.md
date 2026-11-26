# 보안팀 AI 에이전트 오픈소스 6선 — Red/Blue 팀별 실무 비교

[한국어](README.md) | [English](README_en.md)

2026년 기준, 보안팀이 바로 실무에 얹을 수 있는 AI 에이전트 오픈소스를 정리했습니다. 아카이브된 프로젝트는 제외하고 Docker·MCP 기반으로 활성 개발 중인 도구만 골랐습니다.

## Red Team — 공격 표면 검증

| 도구 | 라이선스 | 규모 | 특징 |
| --- | --- | --- | --- |
| **Strix** | Apache-2.0 | 66.7K★ | 웹·API 취약점 탐색 → 실제 PoC 검증 → 코드 패치 제안 |
| **PentAGI** | MIT | 25.2K★ | Docker 완전 격리 기반 멀티 에이전트 자율 침투 테스트 |
| **CyberStrike** | CLI | 13 agents | 기존 Claude·OpenAI 키 연결로 터미널 즉시 실행, 120+ OWASP, MITRE ATT&CK 매핑 보고서 자동 생성 |

> PentAGI는 유명했던 CAI가 2026.08 아카이브되어 목록에서 제외했습니다.

## Blue · Purple Team — 탐지·조사 자동화

| 도구 | 라이선스 | 특징 |
| --- | --- | --- |
| **Vigil** (DeepTempo) | Apache-2.0 | MCP로 SIEM·EDR 연동, 사내망 로컬 Ollama 지원, 13개 SOC 에이전트. 호스트 격리 같은 파괴적 조치는 사람 승인 대기 |
| **SIEMTriage** | Claude Agent SDK | MS Sentinel·Defender XDR 초기 15분 조사 자동화, KQL 헌팅, VirusTotal·GreyNoise 근거 리포트 |
| **Ares + DreadGOAD** | MIT | Red 7개 vs Blue 4개 에이전트가 같은 인프라에서 공방, 실시간 로그 대조로 탐지 룰 빈틈(Gap) 발견 |

## 도입 가드레일

- [ ] 격리망에서 먼저 실행, 외부 인터넷은 Allowlist만
- [ ] 파괴적 액션(호스트 격리·계정 잠금·삭제)은 **사람 승인 게이트** 필수
- [ ] 에이전트가 쓰는 SIEM·클라우드 자격증명은 읽기 전용·단기 토큰
- [ ] 프롬프트·로그에 고객 PII가 들어가지 않도록 마스킹
- [ ] 로컬 LLM(Ollama 등) 사용 시 모델·프롬프트를 사내망 밖으로 내보내지 않는지 확인
- [ ] 에이전트 실행 로그를 별도 보관 (감사·재현용)

## 출처

- Vigil (DeepTempo): https://github.com/Vigil-SOC/vigil

확인 기준일: 2026-11-26. 스타 수·기능은 변동됩니다. 각 프로젝트 저장소의 라이선스와 최근 커밋을 직접 확인하세요.
