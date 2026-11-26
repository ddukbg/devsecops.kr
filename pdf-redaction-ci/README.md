# PDF 비식별화 — 검은 네모는 삭제가 아니다

[한국어](README.md) | [English](README_en.md)

서울중앙지법 2010~2026년 판결문 10건(230명+ 성명·주민번호·범죄경력)에서 검은 네모로 가린 개인정보가 편집·AI 판독만으로 복원되는 결함이 확인됐습니다. 원인은 단순합니다. **PDF 내부 텍스트 객체를 지우지 않고 검은 사각형(Annotation)만 위에 덧씌웠기** 때문입니다.

## 왜 위험한가

- PDF의 텍스트 레이어는 그대로 남아 있어 복사·검색·`pdftotext` 추출로 원문이 나옵니다.
- 주석(Annotation)·메타데이터·숨은 레이어에도 원문이 남습니다.
- HWP는 변경 추적·메모에 작성자와 원본이 남을 수 있습니다.
- 문서를 이미지로 "가렸다"고 생각해도 OCR을 켠 채 다시 PDF로 만들면 텍스트가 복원됩니다.

## 실무 3중 방어

### 1. 진짜 삭제 또는 래스터화

- Acrobat 등에서 **Apply Redactions**로 표적 텍스트 객체를 삭제
- 또는 고해상도 PNG로 래스터화한 뒤 **OCR OFF** 상태로 PDF 재결합

### 2. 메타데이터·숨은 데이터 제거

```bash
# PDF XMP 메타데이터·주석 등 일괄 제거 (exiftool)
exiftool -all= -overwrite_original document.pdf
```

- HWP는 변경 추적·메모를 별도로 해제하고 저장
- 숨긴 레이어·폼 필드·첨부 파일도 함께 확인

### 3. 업로드 파이프라인 자동 차단

`pdftotext`(또는 `pypdf`)로 텍스트를 강제 추출한 뒤 주민번호·계좌·전화번호 정규식이 1건이라도 걸리면 게시를 거부합니다.

[`check_pdf_redaction.sh`](check_pdf_redaction.sh) — 이 검사를 CI에 넣는 예시입니다.

```bash
bash check_pdf_redaction.sh document.pdf
# 위반이 있으면 종료코드 1
```

## 체크리스트

- [ ] 도형 덮기 금지, Apply Redactions 또는 래스터화 사용
- [ ] 배포 전 `pdftotext` 추출 검사 (원문 잔존 여부)
- [ ] `exiftool -all=` 로 메타데이터·주석 제거
- [ ] HWP 변경 이력·메모·작성자 제거
- [ ] 업로드 파이프라인에 정규식 게이트 + 실패 시 알림
- [ ] 외부 공개 문서는 담당자 2인 검수

## 출처

- 파이낸셜뉴스 — 서울중앙지법 판결문 비식별화 결함: https://www.fnnews.com/news/202611231750021070
- 데일리시큐 — 판결문 개인정보 노출: https://www.dailysecu.com/news/articleView.html?idxno=209679

확인 기준일: 2026-11-26.
