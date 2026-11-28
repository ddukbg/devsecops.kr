#!/usr/bin/env bash
# check_legacy_rsa_certs.sh — 레거시 RSA 키 · 약한 서명 점검 (읽기 전용)
#
# 배경:
#   2026-11-20 클로드가 관여한 리만 가설(및 디리클레 L-함수 GRH) Lean 증명이 공개되고
#   21일 Lean FRO·Mathlib 이 검증을 마쳤습니다. 이 증명 자체는 RSA·ECC·PQC 를 뚫지 않습니다.
#   줄어드는 것은 '짧은 키'의 수명입니다. 1024-bit RSA 해독 비용을 Cognition 은 약 $30M 로
#   추정했고, NIST 는 이미 1024-bit RSA 를 폐기 권고했습니다. 남은 키는 대개
#     ① 오래된 웹 인증서 ② 이메일 보안 레코드(DKIM) ③ 디바이스 펌웨어
#   에 남아 있습니다. 이 스크립트는 그 세 곳을 읽기만 해서 찾아냅니다.
#
# 이 스크립트가 하는 일 (모두 읽기 전용):
#   1. TLS 엔드포인트에 접속(openssl s_client)해 서버 인증서를 받아 키 길이·서명 알고리즘·만료 확인
#   2. 로컬 PEM/DER 인증서 파일·디렉터리 점검
#   3. DKIM 공개키 레코드(dig TXT)의 키 길이 확인
#   인증서를 발급·교체·삭제하지 않고, 어떤 설정도 바꾸지 않습니다. 네트워크 읽기 외에는 부작용이 없습니다.
#
# 사용법:
#   bash check_legacy_rsa_certs.sh --hosts hosts.txt
#   bash check_legacy_rsa_certs.sh --host example.com:443 --host legacy.internal:8443
#   bash check_legacy_rsa_certs.sh --pem ./certs --pem ./firmware/device.pem
#   bash check_legacy_rsa_certs.sh --dkim default:example.com --dkim google:example.com
#   bash check_legacy_rsa_certs.sh --hosts hosts.txt --pem ./certs --json out.json --csv
#   bash check_legacy_rsa_certs.sh --hosts hosts.txt --strict      # 발견 사항이 있으면 종료코드 1
#
# 옵션:
#   --host H[:PORT]   점검할 TLS 엔드포인트 (반복 가능, 기본 포트 443)
#   --hosts FILE      한 줄에 하나씩 host 또는 host:port (빈 줄·# 주석 허용)
#   --pem PATH        인증서 파일 또는 디렉터리 (반복 가능). .pem .crt .cer .der 를 읽습니다
#   --dkim S:D        DKIM selector:domain 의 TXT 레코드 확인 (반복 가능)
#   --min-bits N      RSA 최소 허용 비트 (기본 2048)
#   --days N          만료 임박 기준 일수 (기본 30)
#   --timeout N       접속 타임아웃 초 (기본 8)
#   --csv             결과를 CSV 로 출력
#   --json FILE       결과를 JSON 으로 저장
#   --strict          발견 사항이 있으면 종료코드 1
#   -h, --help        이 도움말
#
# 종료코드: 0 발견 없음, 1 --strict 조건 충족(발견 있음), 2 인자·환경 오류
#
# 필요: bash 3.2+, openssl, python3. dig 는 --dkim 사용 시에만 필요합니다.

set -uo pipefail

MIN_BITS=2048
DAYS=30
TIMEOUT=8
STRICT=0
CSV=0
JSON_OUT=""
HOSTS_FILE=""
HOST_ARGS=()
PEM_ARGS=()
DKIM_ARGS=()

usage() {
  sed -n '2,47p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST_ARGS+=("${2:-}"); shift 2 ;;
    --hosts) HOSTS_FILE="${2:-}"; shift 2 ;;
    --pem) PEM_ARGS+=("${2:-}"); shift 2 ;;
    --dkim) DKIM_ARGS+=("${2:-}"); shift 2 ;;
    --min-bits) MIN_BITS="${2:-2048}"; shift 2 ;;
    --days) DAYS="${2:-30}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-8}"; shift 2 ;;
    --csv) CSV=1; shift ;;
    --json) JSON_OUT="${2:-}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v openssl >/dev/null 2>&1 || { echo "openssl 이 필요합니다." >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 가 필요합니다." >&2; exit 2; }

case "$MIN_BITS" in ''|*[!0-9]*) echo "--min-bits 는 숫자여야 합니다." >&2; exit 2 ;; esac
case "$DAYS" in ''|*[!0-9]*) echo "--days 는 숫자여야 합니다." >&2; exit 2 ;; esac

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/rsa-audit.XXXXXX")"
cleanup() { rm -rf "$TMPD"; }
trap cleanup EXIT

# ---------------------------------------------------------------- 수집
# 각 점검 대상은 "<source>\t<target>\t<pem 경로>" 한 줄로 남깁니다.
: > "$TMPD/targets.tsv"
IDX=0

add_pem() {  # add_pem <source> <target> <pemfile>
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$TMPD/targets.tsv"
}

collect_host() {  # collect_host <spec>
  local spec="$1" host port pem
  host="${spec%%:*}"
  if [ "$host" = "$spec" ]; then port=443; else port="${spec##*:}"; fi
  [ -z "$host" ] && return 0
  IDX=$((IDX + 1))
  pem="$TMPD/host_${IDX}.pem"
  if ! openssl s_client -connect "${host}:${port}" -servername "$host" \
        -showcerts </dev/null >"$TMPD/s_client_${IDX}.txt" 2>/dev/null; then
    echo "  [skip] ${host}:${port} — TLS 접속 실패(타임아웃·차단·평문 포트일 수 있음)" >&2
    return 0
  fi
  python3 - "$TMPD/s_client_${IDX}.txt" > "$pem" <<'PYEOF'
import sys
d = open(sys.argv[1], encoding="utf-8", errors="replace").read()
i = d.find("-----BEGIN CERTIFICATE-----")
j = d.find("-----END CERTIFICATE-----", i + 1)
sys.stdout.write(d[i:j + 25] + "\n" if i >= 0 and j > i else "")
PYEOF
  if [ ! -s "$pem" ]; then
    echo "  [skip] ${host}:${port} — 인증서를 받지 못했습니다" >&2
    return 0
  fi
  add_pem "tls" "${host}:${port}" "$pem"
}

collect_pem_path() {  # collect_pem_path <path>
  local p="$1" f
  if [ -d "$p" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      add_pem "file" "$f" "$f"
    done < <(find "$p" -type f \( -name '*.pem' -o -name '*.crt' -o -name '*.cer' -o -name '*.der' \) 2>/dev/null | sort)
  elif [ -f "$p" ]; then
    add_pem "file" "$p" "$p"
  else
    echo "  [skip] $p — 파일·디렉터리가 없습니다" >&2
  fi
}

collect_dkim() {  # collect_dkim <selector:domain>
  local spec="$1" sel dom txt key bits
  sel="${spec%%:*}"; dom="${spec#*:}"
  if [ "$sel" = "$spec" ] || [ -z "$dom" ]; then
    echo "  [skip] $spec — 'selector:domain' 형식이 아닙니다" >&2
    return 0
  fi
  if ! command -v dig >/dev/null 2>&1; then
    echo "  [skip] ${sel}._domainkey.${dom} — dig 가 없어 DKIM 을 확인할 수 없습니다" >&2
    return 0
  fi
  txt="$(dig +short TXT "${sel}._domainkey.${dom}" 2>/dev/null | tr -d '"\n' | tr -d ' ')"
  if [ -z "$txt" ]; then
    printf 'dkim\t%s\t-%s\t-\t-\t-\t-\tNO_RECORD\n' "_domainkey.${dom}" "$sel" >> "$TMPD/dkim.tsv"
    return 0
  fi
  key="$(printf '%s' "$txt" | tr ';' '\n' | sed -n 's/^[[:space:]]*p=//p' | tr -d '\r\n')"
  if [ -z "$key" ]; then
    printf 'dkim\t%s\t-%s\t-\t-\t-\t-\tNO_KEY\n' "_domainkey.${dom}" "$sel" >> "$TMPD/dkim.tsv"
    return 0
  fi
  printf '%s' "$key" | base64 -d > "$TMPD/dkim_${IDX}.der" 2>/dev/null
  bits="$(openssl pkey -pubin -inform DER -in "$TMPD/dkim_${IDX}.der" -noout -text 2>/dev/null \
          | sed -n 's/.*(\([0-9][0-9]*\) bit).*/\1/p' | head -1)"
  alg="RSA"
  printf '%s' "$txt" | grep -qi 'k=ed25519' && alg="Ed25519"
  [ -z "$bits" ] && bits="-"
  printf 'dkim\t%s\t-%s\t-\t-\t%s\t%s\tOK\n' "_domainkey.${dom}" "$sel" "$alg" "$bits" >> "$TMPD/dkim.tsv"
}

: > "$TMPD/dkim.tsv"
for spec in "${HOST_ARGS[@]+"${HOST_ARGS[@]}"}"; do collect_host "$spec"; done
if [ -n "$HOSTS_FILE" ]; then
  [ -f "$HOSTS_FILE" ] || { echo "--hosts 파일이 없습니다: $HOSTS_FILE" >&2; exit 2; }
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -z "$line" ] && continue
    collect_host "$line"
  done < "$HOSTS_FILE"
fi
for p in "${PEM_ARGS[@]+"${PEM_ARGS[@]}"}"; do collect_pem_path "$p"; done
for spec in "${DKIM_ARGS[@]+"${DKIM_ARGS[@]}"}"; do collect_dkim "$spec"; done

# ---------------------------------------------------------------- 분석
OUT="$(
python3 - "$TMPD/targets.tsv" "$TMPD/dkim.tsv" "$MIN_BITS" "$DAYS" "$CSV" "$JSON_OUT" <<'PY'
import json, os, subprocess, sys, datetime

def now_utc():
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)

targets_path, dkim_path, min_bits, days, csv_mode, json_out = sys.argv[1:7]
min_bits = int(min_bits); days = int(days); csv_mode = int(csv_mode)

def openssl_text(path):
    for inform in (None, "DER"):
        cmd = ["openssl", "x509", "-in", path, "-noout", "-text"]
        if inform:
            cmd[2:2] = ["-inform", inform]
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode == 0 and "Certificate:" in p.stdout:
            return p.stdout
    return ""

def openssl_dates(path):
    p = subprocess.run(["openssl", "x509", "-in", path, "-noout", "-startdate", "-enddate"],
                       capture_output=True, text=True)
    raw = {}
    for line in p.stdout.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            raw[k.strip()] = v.strip()
    return raw

def parse_date(s):
    for fmt in ("%b %d %H:%M:%S %Y %Z", "%Y-%m-%d %H:%M:%S %Z"):
        try:
            return datetime.datetime.strptime(s, fmt)
        except Exception:
            pass
    return None

def text_field(pattern, text):
    for line in text.splitlines():
        s = line.strip()
        if s.startswith(pattern):
            return s[len(pattern):].strip()
    return ""

def parse_cert(path):
    text = openssl_text(path)
    if not text:
        return None
    bits = ""
    alg = ""
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("Public Key Algorithm:"):
            alg = s.split(":", 1)[1].strip()
        if s.startswith("Public-Key:"):
            inner = s[s.find("(") + 1: s.find(")")]
            bits = inner.split()[0]
    if not bits:
        m = [l for l in text.splitlines() if "( " in l or "(" in l and "bit" in l]
        if m:
            import re
            mm = re.search(r"\((\d+) bit\)", m[0])
            if mm:
                bits = mm.group(1)
    sig = text_field("Signature Algorithm:", text)
    subject = text_field("Subject:", text)
    issuer = text_field("Issuer:", text)
    dates = openssl_dates(path)
    not_after = dates.get("notAfter", "")
    not_before = dates.get("notBefore", "")
    exp = parse_date(not_after) if not_after else None
    now = now_utc()
    flags = []
    if "rsa" in alg.lower() and bits.isdigit() and int(bits) < min_bits:
        flags.append("WEAK_KEY")

    low = sig.lower()
    if "sha1" in low or "md5" in low:
        flags.append("WEAK_SIG")
    if exp is None:
        flags.append("NO_EXPIRY")
    elif exp < now:
        flags.append("EXPIRED")
    elif (exp - now).days <= days:
        flags.append("EXPIRING")
    status = "+".join(flags) if flags else "OK"
    a = alg.lower()
    disp = "RSA" if "rsa" in a else ("EC" if "ecpublickey" in a or a == "ec" else ("Ed25519" if "ed25519" in a else (alg or "-")))
    return dict(alg=disp, key_alg_raw=alg, bits=bits, sig=sig, subject=subject, issuer=issuer,
                not_before=not_before, not_after=not_after,
                days_left=(exp - now).days if exp else "", status=status)

rows = []
issues = 0
if os.path.exists(targets_path):
    for line in open(targets_path, encoding="utf-8"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 3:
            continue
        source, target, path = parts
        info = parse_cert(path)
        if info is None:
            continue
        row = dict(source=source, target=target, **info)
        rows.append(row)
        if info["status"] != "OK":
            issues += 1

dkim_rows = []
if os.path.exists(dkim_path):
    for line in open(dkim_path, encoding="utf-8"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 8:
            continue
        _, target, sel, subject, issuer, alg, bits, status = parts
        if alg == "RSA" and bits.isdigit() and int(bits) < min_bits:
            status = "WEAK_KEY"
        if status in ("NO_RECORD", "NO_KEY") or status == "WEAK_KEY":
            issues += 1
        dkim_rows.append(dict(target=target, selector=sel, alg=alg, bits=bits, status=status))

if csv_mode:
    print("source,target,key_alg,key_bits,sig_alg,not_after,status,subject")
    for r in rows:
        print("%s,%s,%s,%s,%s,%s,%s,\"%s\"" % (
            r["source"], r["target"], r["alg"], r["bits"], r["sig"],
            r["not_after"], r["status"], r["subject"].replace('"', "'")))
    for d in dkim_rows:
        print("dkim,%s,%s,%s,-,-,%s,selector=%s" % (
            d["target"], d["alg"], d["bits"], d["status"], d["selector"]))
else:
    if not rows and not dkim_rows:
        print("   점검 대상이 없습니다. --host / --hosts / --pem / --dkim 중 하나를 지정하세요.")
    if rows:
        print("CERTIFICATES  (%d개)" % len(rows))
        for r in sorted(rows, key=lambda x: (x["status"] == "OK", x["target"])):
            mark = "OK  " if r["status"] == "OK" else "FIND"
            name = os.path.basename(r["target"]) if r["source"] == "file" else r["target"]
            print("   [%s] %-30s %-6s %-5s %-24s %s" % (
                mark, name[:30], r["alg"][:6],
                (r["bits"] + "b") if r["bits"] else "-", r["sig"][:24], r["status"]))
            if r["status"] != "OK":
                print("          subject: %s" % (r["subject"][:110]))
                print("          expires: %s (D%s)" % (r["not_after"], r["days_left"]))
    if dkim_rows:
        print("DKIM          (%d개)" % len(dkim_rows))
        for d in dkim_rows:
            mark = "OK  " if d["status"] == "OK" else "FIND"
            print("   [%s] %-28s %-8s %-5s %s" % (
                mark, d["target"][:28], d["alg"],
                (d["bits"] + "b") if d["bits"].isdigit() else "-", d["status"]))
    print("")
    print("   RSA 최소 %d bit · 만료 임박 %d일 기준 · 발견 %d건" % (min_bits, days, issues))

if json_out:
    payload = dict(
        generated_at=now_utc().replace(microsecond=0).isoformat() + "Z",
        min_bits=min_bits, days=days,
        certificates=[{k: r[k] for k in ("source", "target", "alg", "key_alg_raw", "bits", "sig",
                                         "subject", "issuer", "not_before", "not_after",
                                         "days_left", "status")} for r in rows],
        dkim=dkim_rows,
        issue_count=issues,
    )
    with open(json_out, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print("   JSON: %s" % json_out)

print("ISSUE_COUNT=%d" % issues)
print("CHECKED=%d" % (len(rows) + len(dkim_rows)))
PY
)"

# ---------------------------------------------------------------- 출력
printf '%s\n' "$OUT" | grep -v '^ISSUE_COUNT=' | grep -v '^CHECKED='
COUNT="$(printf '%s\n' "$OUT" | sed -n 's/^ISSUE_COUNT=//p' | head -1)"
[ -z "$COUNT" ] && COUNT=0
CHECKED="$(printf '%s\n' "$OUT" | sed -n 's/^CHECKED=//p' | head -1)"
[ -z "$CHECKED" ] && CHECKED=0

echo ""
echo "-- next"
echo "   1) WEAK_KEY(RSA < ${MIN_BITS}) 는 교체 대상 목록으로 옮깁니다 — 웹 인증서·DKIM·펌웨어 순서"
echo "   2) WEAK_SIG(SHA-1/MD5) 는 같은 키라도 재발급이 필요합니다 (서명 알고리즘은 키에 붙지 않습니다)"
echo "   3) 알고리즘을 설정으로 바꿀 수 있는지(Crypto-Agility)를 이 목록과 함께 확인합니다"
echo "   4) 10년 이상 비밀 유지가 필요한 데이터부터 PQC 전환 순서를 앞으로 당깁니다 (NIST 2030/2035)"
echo ""
echo "   이 스크립트는 인증서를 발급·교체·삭제하지 않습니다. 목록만 만듭니다."

if [ "$STRICT" -eq 1 ] && [ "$COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
