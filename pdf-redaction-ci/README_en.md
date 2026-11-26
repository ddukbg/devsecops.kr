# PDF redaction — a black box is not a deletion

[한국어](README.md) | [English](README_en.md)

In 10 Seoul Central District Court rulings from 2010–2026 (names, resident numbers, and criminal records of 230+ people), personal data covered with black rectangles was recoverable through editing or AI reading. The cause is simple: **the text objects inside the PDF were never removed; a black rectangle (annotation) was drawn on top.**

## Why it is dangerous

- The PDF text layer remains, so copying, searching, or `pdftotext` extraction reveals the original.
- Annotations, metadata, and hidden layers also retain text.
- HWP files can keep the author and original content in change tracking and memos.
- "Hiding" by converting to an image and then re-creating a PDF with OCR enabled restores the text.

## Three layers of defense

### 1. True redaction or rasterization

- Use **Apply Redactions** in Acrobat or a similar tool to delete the targeted text objects
- Or rasterize to a high-resolution PNG and rebuild the PDF **with OCR off**

### 2. Remove metadata and hidden data

```bash
# Strip PDF XMP metadata, annotations, etc. (exiftool)
exiftool -all= -overwrite_original document.pdf
```

- For HWP, disable change tracking and memos separately before saving
- Check hidden layers, form fields, and embedded files too

### 3. Automatic blocking in the upload pipeline

Force text extraction with `pdftotext` (or `pypdf`); if even one resident-number, account-number, or phone-number pattern matches, reject the upload.

[`check_pdf_redaction.sh`](check_pdf_redaction.sh) — an example of wiring that check into CI.

```bash
bash check_pdf_redaction.sh document.pdf
# Exit code 1 when a violation is found
```

## Checklist

- [ ] No shape overlays; use Apply Redactions or rasterization
- [ ] `pdftotext` extraction check before distribution (residual plaintext)
- [ ] `exiftool -all=` to remove metadata and annotations
- [ ] Remove HWP change history, memos, and author
- [ ] Regex gate in the upload pipeline + alert on failure
- [ ] Two-person review for externally published documents

## References

- Financial News — Seoul Central District Court redaction defect: https://www.fnnews.com/news/202611231750021070
- Daily Secu — personal data in court rulings: https://www.dailysecu.com/news/articleView.html?idxno=209679

Verified as of 2026-11-26.
