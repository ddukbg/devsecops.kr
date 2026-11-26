# OpenShell — AI 에이전트를 OS 커널 수준에서 격리하는 CNCF Sandbox 프로젝트

[한국어](README.md) | [English](README_en.md)

NVIDIA가 Red Hat·Docker·Canonical과 함께 공개한 오픈소스 런타임 **OpenShell**이 2026-11-10 CNCF Sandbox에 합류했습니다. 핵심은 프롬프트 가드레일이 아니라 **OS 커널 수준 격리**입니다. 에이전트가 셸을 실행해도 호스트 파일·프로세스에 닿지 못하게 하는 계층입니다.

## 한눈에

| 항목 | 내용 |
| --- | --- |
| 프로젝트 | OpenShell (NVIDIA + Red Hat, Docker, Canonical) |
| 거버넌스 | CNCF Sandbox (2026-11-10) |
| 구현 | Rust, Apache-2.0 |
| 격리 | Linux Landlock + seccomp 기반 커널 수준 샌드박스 |
| 저장소 | GitHub 21.9k★, 릴리스 v0.1.9 |
| 설치 | `curl -LsSf https://raw.githubusercontent.com/ai-openshell/openshell/main/install.sh | sh` |

## 왜 필요한가

AI 코딩 에이전트는 이제 코드를 쓰고 실행합니다. 컨테이너 격리만으로는 에이전트가 실행한 셸이 마운트된 시크릿, 홈 디렉터리, 다른 프로세스에 접근하는 것을 막기 어렵습니다. OpenShell은 에이전트 실행 단위마다 파일·프로세스·네트워크 규칙을 커널에서 강제합니다.

## 도입 전 알아야 할 한계

- **CNCF Sandbox 0.1.x는 실험 단계입니다.** CLI와 정책 스키마가 바뀔 수 있습니다.
- 파일·프로세스 규칙은 **수동으로 고정**해야 합니다. 자동 학습·자동 최소화는 없습니다.
- 샌드박스 밖의 **클라우드·K8s API 권한은 막지 못합니다.** 에이전트가 가진 IAM 권한은 그대로 유효합니다.

따라서 OpenShell만 붙이면 끝이 아니라, **IAM 최소권한 + 사람 승인 게이트**가 별도로 필요합니다.

## 실무 적용 순서

1. 에이전트 실행 환경에 OpenShell 적용, 기본 정책으로 파일·프로세스 범위 확인
2. 에이전트가 쓰는 클라우드 자격증명을 **워크로드 아이덴티티·단기 토큰**으로 교체
3. 파괴적 작업(삭제·배포·권한 변경)은 **사람 승인 게이트** 뒤에 배치
4. 정책 파일을 Git으로 관리하고, 에이전트별 허용 경로·도메인을 코드리뷰

## 출처

- CNCF — Welcoming OpenShell to the CNCF (2026-11-10): https://www.cncf.io/blog/2026/11/10/welcoming-openshell-to-the-cncf-open-governance-to-secure-agentic-ai/
- GitHub — ai-openshell/openshell: https://github.com/ai-openshell/openshell

확인 기준일: 2026-11-26. 0.1.x API는 변경될 수 있으니 저장소 릴리스 노트를 확인하세요.
