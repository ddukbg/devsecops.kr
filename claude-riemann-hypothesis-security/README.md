# 클로드가 푼 리만 가설 — 내 계좌·RSA 암호는 뚫렸나

[한국어](README.md) | [English](README_en.md)

2026년 11월 20일, 앤트로픽 소속 수학자 레벤트 알포게(Levent Alpöge)가 클로드와 함께 찾은 **리만 가설** 증명을 Lean 라이브러리로 공개했습니다. 이틀 뒤인 21일 Lean FRO와 Mathlib 이니셔티브가 "명제와 증명이 모두 옳다"고 공동 성명을 냈고, MIT의 앤드류 서덜랜드가 독립 검증표를 공개했습니다.

결론부터: **이 증명은 RSA-2048, ECC, 양자내성암호(PQC)를 뚫지 않습니다.** 실제로 달라진 것은 ① "GRH가 참이라면"이라는 단서가 붙어 있던 정리들이 조건 없이 확정된 것, ② AI 에이전트와 형식 검증(Lean) 조합이 사람이 한눈에 담을 수 없는 규모의 논증을 완주했다는 사실입니다. 수명이 줄어드는 것은 **1024-bit RSA 같은 짧은 키**입니다.

## 한눈에

| 항목 | 내용 |
| --- | --- |
| 사건 | 2026-11-20 레벤트 알포게(앤트로픽)가 클로드와 약 6주 협업해 리만 가설 및 디리클레 L-함수 GRH 증명을 Lean 으로 공개 |
| 규모 | **175,187개 파일 · 17,374,215줄** (코드 15,531,759줄), 압축 239MB · 논문 없이 4쪽 개요(`remark.pdf`)만 |
| 검증 | 2026-11-21 **Lean FRO · Mathlib 공동 성명** — 명제와 증명 모두 옳다고 인증. 서덜랜드(MIT) 검증표는 2026-11-27 전 항목 완료 |
| 공리 | 핵심 정리 5개가 의존하는 공리는 표준 3개(`propext`, `Classical.choice`, `Quot.sound`)뿐 |
| 범위 | 여기서 말하는 GRH는 **디리클레 L-함수**까지 — 데데킨트 ζ·헤케 L·보형 L-함수는 검증 대상이 아님 |
| 암호 영향 | **RSA-2048 · ECC · PQC 영향 없음.** 1024-bit RSA 같은 레거시 짧은 키의 수명만 줄어듦 |
| 실무 조치 | 패닉 교체 아님 — ① 암호 자산 인벤토리 ② 1024-bit 퇴출 ③ Crypto-Agility ④ PQC 로드맵 가속 |
| 점검 | [check_legacy_rsa_certs.sh](check_legacy_rsa_certs.sh) — 웹 인증서·로컬 PEM·DKIM 에서 RSA < 2048 · SHA-1 탐지 (읽기 전용) |

> 클레이수학연구소는 여전히 리만 가설을 **미해결**로 분류합니다. 기계 검증을 통과한 것과 수학계가 증명을 이해하고 인정한 것은 다른 일이고, 25만 쪽 분량의 아이디어를 해독하는 데는 수개월이 걸린다는 것이 참여 수학자들의 관측입니다.

## 1. 무슨 일이 있었나

- 알포게는 증명을 논문이 아니라 **Lean 4 라이브러리**로 공개했습니다. 완전히 상세한 논문은 "읽을 수 없을 만큼 길다"며 직접 쓰지 않았고, 개요 4쪽에 250,000쪽이 넘는 초안이 있다는 각주만 남겼습니다.
- Lean FRO와 Mathlib은 제나(Xena) 블로그의 증명 검증 기준 네 가지 — **명제가 맞는지 / 코드가 컴파일되는지 / 코드가 그 명제를 증명하는지 / 증명이 논리적으로 타당한지** — 를 모두 확인했습니다.
- 서덜랜드의 검증은 별도 커널로 이어졌습니다. Rust 로 독립 구현된 `nanoda`, 린 개발진의 `con-leche`, 그 Rust 포팅 `con-ron`, 린으로 린 커널을 다시 구현한 `lean4lean`, 그리고 공식 비교 도구 `Comparator`가 모두 통과했습니다. 샌드박스에서 다시 빌드한 결과물은 공개된 것과 바이트 단위로 같았습니다.
- **에이전트가 만든 산출물을, 다른 에이전트(서덜랜드는 클로드 코드로 검증)와 독립 커널들이 확인**한 구조입니다. 사람이 논증을 다 이해하기 전에 기계가 먼저 '옳다'를 확정한 첫 대형 사례입니다.

## 2. 왜 '암호 붕괴'로 읽혔나 — 세 가지를 구분하면 끝

| 구분 | 내용 | 이번 증명 |
| --- | --- | --- |
| 소수 분포 | 소수가 수직선에 얼마나 촘촘히, 얼마나 고르게 놓이는가(π(x)와 Li(x)의 오차). 리만 가설이 말하는 것 | **확정** |
| 소수 판별 | 주어진 수가 소수인지 결정하는 문제. GRH를 전제로 한 정리들이 여기 걸려 있음 | **조건부 → 무조건부** |
| 소인수분해 | n = p × q 에서 p, q 를 찾는 일. RSA가 기대는 문제 | **변화 없음** |

"소수 비밀이 풀렸다"는 헤드라인이 나오면 대개 세 번째를 첫 번째로 착각한 것입니다. 분포를 알아도 당신의 키 안에 든 두 소수가 무엇인지는 알 수 없습니다.

> "The proof leaves RSA exactly as strong as it was last week." — Frank Dickson, Dickson Research (Computerworld, 2026-11-23)

## 3. 일반인 · IT 측면에서 실제로 달라진 것

- **일반인**: 은행·메신저·지갑의 세션과 인증서는 그대로입니다. 리만 가설은 소수의 분포 정리이고, 소인수분해 알고리즘이 아닙니다.
- **IT·수학**: GRH를 전제로 쓰이던 결과들이 조건 없이 확정됐습니다. 대표가 1976년 게리 밀러의 **결정론적 소수 판별법**입니다(배흐 1990이 그 비용을 계산했습니다). 다만 실무 코드는 바뀌지 않습니다.
  - 2002년 AKS 테스트가 이미 가정 없이 다항시간 결정론적 판별을 합니다.
  - 실제 라이브러리는 속도와 오류 한계가 증명된 **Miller-Rabin 확률적 테스트**를 몇십 번 돌립니다. FIPS 186-5의 RSA 소수 생성도 이 방식입니다.
- **전환점**: 증명 자체보다, **AI 에이전트 + Lean 형식 검증**이 1,700만 줄 규모를 커널 검증까지 끌고 간 워크플로가 실증된 쪽이 큽니다.

## 4. 보안 측면 — 안전한 것과 줄어드는 것

**안전한 것(당장)**

| 알고리즘 | 기대는 문제 | 상태 |
| --- | --- | --- |
| RSA-2048 | 소인수분해 | 영향 없음 — 고전 컴퓨터 기준 안전 |
| ECDSA / ECDH P-256 | 타원곡선 이산로그 | 영향 없음 |
| ML-KEM 등 PQC | 격자 문제(Module-LWE 등) | 영향 없음 |

**줄어드는 것(중장기)**

- **1024-bit RSA**: NIST가 이미 폐기 권고했지만 구형 웹 인증서, 이메일 보안 레코드, 디바이스 펌웨어에 남아 있습니다. Cognition은 1024-bit 키 하나를 푸는 비용을 GPU 시간 기준 **약 3,000만 달러**로 추정합니다. 국가급 행위자에게는 불가능이 아니라 예산 항목입니다.
- **AI가 만드는 가속**: AI 에이전트가 기존 소인수분해 소프트웨어를 GPU용으로 다시 써서 비용을 10분의 1 수준으로 낮췄습니다. "지름길을 찾은 게 아니라 먼 길을 싸게 만든" 경우입니다.
- **PQC 후보도 늦게 깨진다**: 2026년 7월 클로드 미토스가 양자내성 서명 후보 HAWK의 수학에서 결함을 찾았습니다. 수년간 연구된 방식이었습니다. 그래서 **Crypto-Agility**(알고리즘을 설정으로 교체·롤백하는 능력)가 필요합니다.
- **일정**: NIST는 2026-10-27 PQC 전환 계획을 확정했습니다. RSA·ECC는 **2030년 이후 단계적 퇴출**, **2035년 이후 NIST 표준에서 제외**입니다. "AI가 이 일정을 관대해 보이게 만들 수 있다"는 것이 실무자들의 경고입니다.

> "AI is turning encryption strength into a depreciating asset." — Frank Dickson (Computerworld)

## 5. 실무 4단계

1. **암호 자산 인벤토리** — 어디에 무슨 키가 있는지. 외부 인증서 → 이메일 보안 레코드(DKIM) → 펌웨어 순서.
2. **1024-bit 퇴출** — RSA < 2048, SHA-1/MD5 서명, 만료 임박을 목록화하고 교체 티켓으로.
3. **Crypto-Agility** — 알고리즘 교체가 코드 수정이 아니라 설정 변경·롤백으로 되는지 확인. TLS 그룹·서명 알고리즘·KEM 선택이 설정에 있는지부터.
4. **PQC 로드맵 가속** — 10년 이상 비밀이어야 하는 데이터부터 순서를 앞으로. NIST 일정(2030/2035)을 상한선이 아니라 기준선으로.

### 점검 스크립트

```bash
# 1) TLS 엔드포인트 목록 점검 (한 줄에 host 또는 host:port)
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/claude-riemann-hypothesis-security/check_legacy_rsa_certs.sh
bash check_legacy_rsa_certs.sh --hosts hosts.txt --csv

# 2) 로컬 인증서 디렉터리 (PEM/DER, .pem .crt .cer .der)
bash check_legacy_rsa_certs.sh --pem ./certs --json legacy.json

# 3) DKIM 공개키 (selector:domain)
bash check_legacy_rsa_certs.sh --dkim default:example.com --dkim s1:example.com

# 4) CI 게이트: 발견 사항이 있으면 종료코드 1
bash check_legacy_rsa_certs.sh --hosts hosts.txt --strict
```

탐지 항목은 `WEAK_KEY`(RSA < 2048), `WEAK_SIG`(SHA-1/MD5), `EXPIRED`/`EXPIRING`, DKIM `NO_RECORD`/`NO_KEY` 입니다. 인증서를 발급·교체·삭제하지 않고 어떤 설정도 바꾸지 않습니다.

## 6. 교차 확인

| 사실 | 출처 |
| --- | --- |
| 공개일·작성자·규모(1,700만 줄, 25만 쪽) | Scientific American(2026-11-20), Nature(2026-11-20), BBC(2026-11-20), 동아사이언스(2026-11-24), Lean 4 Dev 분석 |
| Lean FRO·Mathlib 검증 성명과 4개 기준 | Lean community blog 공동 성명(2026-11-21), 동아사이언스(2026-11-24) |
| 175,187 파일 / 17,374,215줄, 공리 3개, 커널·Comparator 통과, 샌드박스 재빌드 일치 | math.mit.edu/~drew/grh (서덜랜드 검증표, 2026-11-27 갱신) |
| GRH 범위가 디리클레 L-함수까지 | 서덜랜드 검증표 Scope 항목, 사이언스모니터(2026-11-21) |
| 소수 판별 vs 소인수분해, Miller 1976 → 무조건부, 실무는 Miller-Rabin | Scientific American(2026-11-24), FIPS 186-5 정리 |
| RSA·ECC·PQC 무영향, 1024-bit $30M 추정, NIST 2030/2035, HAWK | Computerworld(2026-11-23) |

**한계와 미확인**

- 3,000만 달러는 RSA-896 해독 결과를 스케일링한 **추정치**입니다. 1024-bit 키를 실제로 푼 사례는 없습니다.
- 증명은 기계 검증을 통과했지만, 수학계의 개념적 이해와 클레이연구소의 판정은 별개입니다.
- 여기서 GRH는 디리클레 L-함수에 한정됩니다. 가장 넓은 의미의 GRH 전체가 아닙니다.

## 7. 참고 링크

- Scientific American — [What does the Riemann hypothesis proof mean for encryption?](https://www.scientificamerican.com/article/why-solving-the-riemann-hypothesis-wont-break-encryption/) (2026-11-24)
- Computerworld — [Encryption has a new problem: AI is getting better at proving the impossible](https://www.computerworld.com/article/4252348/encryption-has-a-new-problem-ai-is-getting-better-at-proving-the-impossible.html) (2026-11-23)
- Lean community blog — [Lean verification of the Riemann Hypothesis](https://leanprover-community.github.io/blog/posts/riemann-hypothesis/) (2026-11-21)
- MIT — [Verification files for the Lean proof](https://math.mit.edu/~drew/grh/index.html)
- GitHub — [leanprover-community/riemann-hypothesis](https://github.com/leanprover-community/riemann-hypothesis)

---

확인 기준일 2026-11-28. 패치·교체 판단은 소속 조직의 보안 정책을 따르세요.
