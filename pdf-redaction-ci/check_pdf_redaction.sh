#!/usr/bin/env bash
# PDF 비식별화 검증 게이트 (예시)
# 텍스트 레이어에 개인정보 패턴이 남아 있으면 종료코드 1로 차단한다.
# 요구사항: poppler-utils (pdftotext)
set -u

if [ "$#" -lt 1 ]; then
  echo "사용법: $0 <file.pdf> [file2.pdf ...]" >&2
  exit 2
fi

if ! command -v pdftotext >/dev/null 2>&1; then
  echo "pdftotext 이 없습니다. poppler-utils 를 설치하세요." >&2
  exit 2
fi

# 주민등록번호, 휴대전화, 계좌번호(하이픈 구분), 이메일
PATTERN='([0-9]{6}[- ]?[1-4][0-9]{6})|(01[016789][- ]?[0-9]{3,4}[- ]?[0-9]{4})|([0-9]{2,6}-[0-9]{2,6}-[0-9]{2,8})|([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})'

status=0
for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "SKIP (파일 없음): $f" >&2
    status=1
    continue
  fi

  text="$(pdftotext -layout "$f" - 2>/dev/null)"
  hits="$(printf '%s\n' "$text" | grep -nE "$PATTERN" | head -n 5)"

  if [ -n "$hits" ]; then
    echo "FAIL: $f — 텍스트 레이어에 개인정보 패턴이 남아 있습니다."
    printf '%s\n' "$hits" | sed 's/^/    /'
    status=1
  else
    echo "OK: $f"
  fi
done

exit "$status"
