# VMware VMSA-2026-0011 — vCenter 인증 우회 · ESX I/O 필터 RCE

[한국어](README.md) | [English](README_en.md)

Broadcom이 2026-11-24 VMware 취약점 23건을 패치했습니다. 이 중 CVSS 9.8 치명적 취약점이 3건입니다. 지난주 제로데이(123890) 패치와 **별개 버그**여서, 이미 패치한 환경도 다시 확인해야 합니다.

## 취약점

| CVE | 대상 | 내용 |
| --- | --- | --- |
| CVE-2026-123903 | vCenter `vmdir` | 네트워크 접근만으로 인증 우회 (CVSS 9.8) |
| CVE-2026-123910 | ESX I/O 필터 | 게스트 권한 없이 호스트 코드 실행 (CVSS 9.8) |
| CVE-2026-123911 | ESX I/O 필터 | 게스트 권한 없이 호스트 코드 실행 (CVSS 9.8) |

- 2026-11-24 기준 **공개 악용·PoC 미보고**. 단, 지난주 `vmdir` 버그는 며칠 만에 KEV에 등재됐습니다.
- 우회 조건: ELM 비활성화 무관. Dell VxRail / HPE 등은 벤더 빌드를 확인해야 합니다.

## 버전별 고정 빌드

| 제품 / 브랜치 | 고정 버전 · 빌드 | 비고 |
| --- | --- | --- |
| vCenter 9.1.x | **9.1.2 (25946533)** | 신규 패치 필수 |
| vCenter 9.0.x | **9.0.2.0300 (25937208)** | 신규 패치 필수 |
| vCenter 8.0 / VCF 5 | **8.0 U3m (25934264)** | 기적용 시 통과 |
| ESX 9.1.x | **ESXi-9.1.2.0-25946735** | 재부팅 필수 |
| ESX 8.0 | **ESXi80U3m-25926933** | 우회 KB463535 |
| ESX 9.0.x | 9.0.2.0200* (Pending) | 매트릭스 재확인 |

## 지난주 패치했어도 방심하면 안 되는 4가지

1. **SAFE** — vCenter 8.0 U3m(25934264)을 이미 올렸다면 vCenter 추가 패치 불필요
2. **TRAP** — vCenter 9.1.1.0200 · 9.0.2.0200으로는 여전히 뚫림 → 9.1.2 / 9.0.2.0300 필수
3. **MISS** — ESX 호스트는 지난주 권고에 없었음 → 별도 패치·재부팅 필수 (Live Patch 미지원, vSAN Witness 포함)
4. **EOL** — vCenter/ESX 7.0은 일반 지원 종료(2025-10-02 EoGS), 공개 패치 없음 → 확장 지원 없으면 업그레이드 외 해결책 없음

## 즉시 조치

1. **vCenter 우회 차단** — 관리 인터페이스(5480)와 `vmdir` 포트를 일반 유저 VLAN·인터넷에서 차단, Admin/Jump Host만 허용
2. **PowerCLI 전수 식별**

```powershell
# 접속 중인 vCenter/ESX 빌드 일괄 조회
$global:DefaultVIServer.Version
$global:DefaultVIServer.Build
```

3. **ESX 다운타임 계획** — Live Patch 미지원이므로 VM 마이그레이션 후 순차 재부팅 (vSAN Witness·Avi LB 포함)

## 출처

- Broadcom — VMSA-2026-0011: https://support.broadcom.com/web/ecx/support-content-notification/-/external/content/SecurityAdvisories/0/39626
- Broadcom — VMSA-2026-0011 Q&A: https://brcm.tech/vmsa-2026-0011-qna

확인 기준일: 2026-11-26. 빌드 번호·패치 상태는 벤더 권고 원문을 확인하세요.
