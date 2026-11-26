# 클라우드 시크릿 연쇄 노출 대응 — Rackspace Spot · Radware · Azure APIM · Argo CD

[한국어](README.md) | [English](README_en.md)

2026년 11월 셋째·넷째 주에 클라우드 플랫폼, WAF, API 게이트웨이, CI/CD에서 시크릿·키 노출 사고가 연달아 확인됐습니다. 공통 교훈은 하나입니다.

> 벤더가 침입 경로를 막아도 **이미 유출된 키는 자동으로 폐기되지 않습니다.**
> 발급처(IAM·Entra·각 콘솔)에서 새 키를 먼저 만들고, 구 키를 지웁니다.

## 한눈에

| 사건 | 확인된 내용 | 실무 영향 |
| --- | --- | --- |
| Rackspace Spot (11/17) | 탈취 자격증명으로 고객 클러스터에 무단 워크로드 실행, Kubernetes Secrets 접근 | 클러스터 시크릿 전면 로테이션, 12/08 서비스 종료 |
| Radware Cloud WAF | 고객 클라우드 접근 키 노출 (S3·Blob 로그 접근용) | 로그 버킷 키 로테이션 |
| Azure API Management Classic | 결함 악용으로 시크릿 탈취 (Microsoft 경고) | APIM 발급 자격증명 점검 |
| Argo CD | GHSA-q4f6-wc8m-r246 | 배포 파이프라인 시크릿 점검 |

## 1. Rackspace Spot — 무슨 일이 있었나

- **2026-11-17 00:20–22:00 UTC**, 공격자가 탈취한 자격증명을 사용해 고객 클러스터에 인가되지 않은 워크로드를 배포하고 **Kubernetes Secrets에 접근**했습니다.
- Rackspace는 Spot 플랫폼을 **2026-12-08 17:00 CST**에 영구 종료한다고 공지했습니다. 워크로드 이관과 키 로테이션을 동시에 해야 합니다.

### Spot 사용자가 지금 할 일

1. Spot 계정에서 **API 토큰 폐기 후 재발급**
2. 새 **kubeconfig** 발급·배포 (구 kubeconfig 폐기)
3. 클러스터의 **모든 시크릿 로테이션** — DB 비밀번호, 클라우드 키, OIDC 클라이언트 시크릿, 서드파티 API 키
4. **11/17 이후** DB 감사 로그, Git 저장소 접근 로그, 클라우드 감사 로그를 소급 조사

### IoC 점검

```bash
# 의심 Pod 이름 접두사로 조회
kubectl get pods -A | grep -E '^(i1|glm-|probe)'
```

- 의심 IP: `23.224.79.106`, 대역 `23.224.0.0/15`
- **11/16 이후** CloudTrail·활동 로그에서 S3 / Azure Blob 접근(`GetObject`, `ListBucket`)을 조회합니다. 정상 배포 시각과 맞지 않는 호출을 먼저 봅니다.

## 2. 키 로테이션 순서

순서를 지키지 않으면 배포가 깨지고, 롤백 압력 때문에 구 키를 다시 살리게 됩니다.

1. **발급처에서 새 키 발급** — AWS IAM, Entra ID, 각 SaaS 콘솔
2. 새 키 배포 및 동작 검증
3. 구 키 **비활성화 → 삭제**
4. 로그에서 구 키의 마지막 사용 시각 확인 (유출 후 사용 흔적)

> 유출된 키를 "일단 비활성화만" 해 두는 것은 로테이션이 아닙니다. 삭제까지 끝내야 합니다.

## 3. 공통 점검 체크리스트

- [ ] 저장소·CI 변수·이미지 레이어에 장기 자격증명이 없는지 (`git log -p`, CI secret 목록)
- [ ] 클라우드 키는 **워크로드 아이덴티티(OIDC) / 인스턴스 역할**로 대체 가능한지
- [ ] 시크릿 매니저 접근 로그에서 비정상 주체·시간대 조회
- [ ] WAF·APIM·CI/CD 도구의 아웃바운드 자격증명 범위 최소화
- [ ] 키 발급처별 담당자와 로테이션 절차 문서화 (사고 때 순서를 묻지 않도록)

## 출처

- BleepingComputer — Rackspace shuts down Spot cloud platform after security breach: https://www.bleepingcomputer.com/news/security/rackspace-shuts-down-spot-cloud-platform-after-security-breach/
- BleepingComputer — Radware discloses breach exposing customer cloud access keys: https://www.bleepingcomputer.com/news/security/radware-discloses-breach-exposing-customer-cloud-access-keys/
- CSO Online — Azure API Management flaw used to steal secrets: https://www.csoonline.com/article/4252513/attackers-exploited-an-azure-api-management-flaw-to-steal-secrets-microsoft-warns.html
- Argo CD security advisory GHSA-q4f6-wc8m-r246: https://github.com/argoproj/argo-cd/security/advisories/GHSA-q4f6-wc8m-r246

확인 기준일: 2026-11-26. 서비스 종료·권고 내용은 변경될 수 있으므로 벤더 공지를 함께 확인하세요.
