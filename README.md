# devsecops.kr

인스타그램 DevSecOps 매거진 [@decsecops.kr](https://www.instagram.com/decsecops.kr/) DM으로 보낸 자료와 점검 스크립트 모음입니다.
DM으로 받은 링크는 이 저장소의 파일을 가리킵니다.

## 목차

| 주제 | 요약 문서 | 점검 스크립트 |
| --- | --- | --- |
| CVE-2026-99362 (NFS2ROOT) | [cve-2026-99362-nfs2root/README.md](cve-2026-99362-nfs2root/README.md) | [check_nfs2root.sh](cve-2026-99362-nfs2root/check_nfs2root.sh) |

## CVE-2026-99362 (NFS2ROOT)

리눅스 커널 NFS 서버(`nfsd`, NFSv4.1 / 4.2, TCP 2049)의 무인증 원격 루트 취득 취약점. CVSS 9.8 Critical, Linux 3.16(2014) 이후 존재.

- 해당: 커널 `nfsd`로 공유를 내보내고 2049가 외부에서 닿는 노드
- 비해당: EFS / FSx를 NFS **클라이언트**로만 마운트하는 EKS 워커 노드·EC2

**문서**: [cve-2026-99362-nfs2root/README.md](cve-2026-99362-nfs2root/README.md) — 개요, AWS·EKS 판별 기준, 고정 커널 버전(6.12.117 · 6.18.61 · 7.3.2 · 7.4-rc1), 임시 완화

**점검 스크립트**: [cve-2026-99362-nfs2root/check_nfs2root.sh](cve-2026-99362-nfs2root/check_nfs2root.sh)

```bash
# 상세 출력
curl -sSL https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/cve-2026-99362-nfs2root/check_nfs2root.sh | sudo bash

# 여러 대 집계용 CSV 한 줄 출력
curl -sSLO https://raw.githubusercontent.com/ddukbg/devsecops.kr/main/cve-2026-99362-nfs2root/check_nfs2root.sh
sudo bash check_nfs2root.sh --csv
```

아래 4가지를 모두 만족하면 취약으로 판정합니다.

1. 커널 내장 NFS 서버(`nfsd`) 동작
2. NFSv4.1 또는 4.2 활성화
3. tcp/2049가 loopback 외 주소에서 리슨
4. 커널에 수정 미반영 (배포판 changelog에 CVE 없음 / 업스트림 버전 미달)

읽기 전용 점검이며 시스템을 변경하지 않습니다. 2049 리슨 프로세스명 확인은 root에서만 됩니다.

`--csv` 출력 컬럼: `host,verdict,kernel,nfsd,v41,listen_ext,listener,exports,patch,nfs_client_mounts`

판정값은 `NOT_AFFECTED`, `LOW`, `PATCHED`, `VULNERABLE`, `REVIEW` 중 하나입니다.
`REVIEW`는 자동 판정이 어려운 경우이므로 OS 벤더 권고를 확인하세요.

종료코드: `0` 해당없음/패치됨, `1` 취약, `2` 확인필요.

> 이 스크립트는 점검 보조용입니다. 패치 적용과 운영 판단은 소속 조직의 보안 정책을 따르세요.
