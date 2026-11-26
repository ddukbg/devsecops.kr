#!/usr/bin/env python3
"""safe_url_check.py — SSRF 방어 예제: 같은 URL을 세 가지 검사로 비교한다.

목적
  SSRF의 근본 원인은 "검증기와 요청 클라이언트가 같은 문자열을 다르게 읽는 것"이다.
  이 파일은 같은 입력을
    ① 부분 문자열 검사  (나쁜 예: if "trusted.com" in url)
    ② URL 파싱 결과 비교 (urlsplit 1회 파싱)
    ③ 해석된 IP 대역 검사 (ipaddress)
  에 통과시켜 어느 검사가 어디서 뚫리는지 출력한다.

중요
  - 외부로 요청을 보내지 않는다. 실제 DNS 조회도 하지 않는다(아래 STUB_DNS 사용).
    운영 코드에서는 socket.getaddrinfo()로 해석한 뒤 ②③을 다시 적용해야 한다.
  - 이 파일은 방어 로직 예제이며, 어떤 대상도 공격하지 않는다.

사용법
  python3 safe_url_check.py            # 표 출력 + 자체 검증(실패 시 종료코드 1)
  python3 safe_url_check.py --quiet    # 자체 검증만

참고
  RFC 3986 §3.2, OWASP SSRF Prevention Cheat Sheet
"""

from __future__ import annotations

import ipaddress
import sys
from urllib.parse import urlsplit

# ── 정책 ─────────────────────────────────────────────────────────────────────
ALLOWED_HOSTS = {"api.trusted.com", "www.trusted.com"}
ALLOWED_SCHEMES = {"http", "https"}

# 사설·예약 대역. 새 대역이 추가되면 여기만 늘리면 된다.
BLOCKED_NETS = [ipaddress.ip_network(n) for n in (
    "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8",
    "169.254.0.0/16", "172.16.0.0/12", "192.168.0.0/16", "198.18.0.0/15",
    "224.0.0.0/4", "240.0.0.0/4",
    "::1/128", "fc00::/7", "fe80::/10",
)]

# 예제용 고정 해석 결과. 실제 코드에서는 socket.getaddrinfo(host, port)를 쓴다.
STUB_DNS = {"api.trusted.com": ["203.0.113.10"], "www.trusted.com": ["203.0.113.11"]}


def check_substring(raw: str) -> bool:
    """나쁜 예: 문자열 안에 허용 도메인이 '들어 있으면' 통과."""
    return any(h in raw for h in ("trusted.com",))


def parse_host(raw: str) -> tuple[str, str]:
    """URL을 정확히 한 번 파싱해 host를 뽑는다. (host, error)"""
    if "\\" in raw:
        return "", "backslash"
    parts = urlsplit(raw)
    if parts.scheme.lower() not in ALLOWED_SCHEMES:
        return "", "scheme"
    # userinfo( user:pass@host )는 허용하지 않는다 — 파서별 해석이 갈리는 대표 지점.
    if "@" in parts.netloc:
        return "", "userinfo"
    host = (parts.hostname or "").lower().rstrip(".")
    if not host:
        return "", "no host"
    return host, ""


def to_ip(host: str) -> ipaddress._BaseAddress | None:  # type: ignore[attr-defined]
    """host를 IP로 해석한다. IP 리터럴이면 그대로, 아니면 STUB_DNS 사용."""
    try:
        return ipaddress.ip_address(host)
    except ValueError:
        pass
    try:  # 10진수 표기: 2852039166
        return ipaddress.ip_address(int(host, 10))
    except (ValueError, TypeError):
        pass
    try:  # 16진수 표기: 0xA9FEA9FE
        if host.lower().startswith("0x"):
            return ipaddress.ip_address(int(host, 16))
    except (ValueError, TypeError):
        pass
    return None


def is_blocked_ip(ip: ipaddress._BaseAddress) -> bool:  # type: ignore[attr-defined]
    mapped = getattr(ip, "ipv4_mapped", None)
    if mapped is not None:
        ip = mapped
    return any(ip in net for net in BLOCKED_NETS)


def check_url(raw: str) -> tuple[str, str, str, str]:
    """(substring, parse, ipcheck, verdict) — PASS/FAIL과 판정 사유를 돌려준다."""
    sub = "PASS" if check_substring(raw) else "FAIL"

    host, err = parse_host(raw)
    if err:
        return sub, "FAIL", "FAIL", f"BLOCK ({err})"

    parse_ok = host in ALLOWED_HOSTS
    if not parse_ok:
        return sub, "FAIL", "FAIL", "BLOCK (host mismatch)"

    ips: list[ipaddress._BaseAddress] = []  # type: ignore[attr-defined]
    literal = to_ip(host)
    if literal is not None:
        ips = [literal]
    else:
        for addr in STUB_DNS.get(host, []):
            ips.append(ipaddress.ip_address(addr))
    if not ips:
        return sub, "PASS", "FAIL", "BLOCK (unresolved)"

    if any(is_blocked_ip(ip) for ip in ips):
        return sub, "PASS", "FAIL", "BLOCK (private ip)"
    return sub, "PASS", "PASS", "ALLOW"


CASES: list[tuple[str, str]] = [
    ("https://api.trusted.com/health", "ALLOW"),
    ("https://169.254.169.254/?from=api.trusted.com", "BLOCK (host mismatch)"),
    ("https://api.trusted.com@169.254.169.254/", "BLOCK (userinfo)"),
    ("http://2852039166/", "BLOCK (host mismatch)"),
    ("http://0xA9FEA9FE/", "BLOCK (host mismatch)"),
    ("http://[::ffff:a9fe:a9fe]/", "BLOCK (host mismatch)"),
    ("https://169.254.169.254/#@api.trusted.com", "BLOCK (host mismatch)"),
    ("https://api.trusted.com./health", "ALLOW"),
    ("file:///etc/passwd", "BLOCK (scheme)"),
    ("https://api.trusted.com\\@169.254.169.254/", "BLOCK (backslash)"),
]


def main() -> int:
    quiet = "--quiet" in sys.argv[1:]
    header = ("payload", "substr", "parse", "ipcheck", "verdict")
    rows = [(raw, *check_url(raw)) for raw, _ in CASES]

    if not quiet:
        width = max(len(header[0]), *(len(r[0]) for r in rows)) + 2
        print(header[0].ljust(width), "substr".ljust(8), "parse".ljust(8),
              "ipcheck".ljust(8), "verdict")
        for raw, sub, parse, ipcheck, verdict in rows:
            print(raw.ljust(width), sub.ljust(8), parse.ljust(8), ipcheck.ljust(8), verdict)
        print()

    failures = 0
    for (raw, expected), (_, _, _, _, verdict) in zip(CASES, rows):
        if expected != verdict:
            failures += 1
            print(f"MISMATCH  {raw}\n  expected: {expected}\n  actual:   {verdict}")

    if failures:
        print(f"\n자체 검증 실패: {failures}건")
        return 1
    print(f"자체 검증 통과: {len(CASES)}건 — 문자열 검사만으로는 "
          f"{sum(1 for c, e in CASES if c.startswith('http') and 'trusted.com' in c and e != 'ALLOW')}건이 통과한다")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
