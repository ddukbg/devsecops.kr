#!/usr/bin/env python3
"""url_validator_example.py — GHSA-pcx2-xcq4-65vf 재현과 안전한 검증 예제

Kyverno < 1.19.2 는 apiCall 의 URLPath 를 파일 경로 함수(path.Clean)로 정리한 뒤
정규식으로 네임스페이스를 뽑았습니다. 실행 단계의 client-go 는 같은 문자열을
net/url 로 파싱해 '?' 뒤를 쿼리로 잘라냈기 때문에, 검증기가 승인한 네임스페이스와
실제로 요청이 도달한 자원이 달라졌습니다.

이 파일은 그 구조를 Python 으로 옮겨
  1) 취약한 검증(vulnerable_is_allowed)과
  2) URL 파서로 먼저 분리하는 안전한 검증(safe_is_allowed)을
6개 케이스로 비교합니다. 마지막에 ?next= 오픈 리다이렉트의 역슬래시 함정을 덧붙입니다.

실행:
    python3 url_validator_example.py

종료코드: 0 모든 기대값 일치, 1 불일치, 2 실행 환경 오류
참고: Go path.Clean 과 Python posixpath.normpath 는 완전히 같지 않습니다
      (Clean("") == ".", normpath 는 선두 "//" 를 보존). 이 예제의 입력에서는
      동작이 같고, 논점인 "'?' 를 경로 문자로 취급한다"는 점도 동일합니다.
"""

import posixpath
import re
import sys
from urllib.parse import unquote, urlsplit

# Kyverno pkg/engine/apicall/apiCall.go 의 namespacePathRegex 와 같은 식
NAMESPACE_PATH_RE = re.compile(r"^/api(s)?/.*?/namespaces/([^/]+)/?.*$")

# 경로 안에 인코딩된 형태로 숨어드는 '?', '#', '\'
ENCODED_CONTROL_RE = re.compile(r"%(3f|23|5c)", re.IGNORECASE)


# ---------------------------------------------------------------------------
# 1) 취약한 검증 — Kyverno 1.19.2 미만의 Fetch() 를 옮긴 것
# ---------------------------------------------------------------------------
def vulnerable_is_allowed(url_path: str, policy_namespace: str):
    """검증기만 볼 때의 판정. 실행기가 무엇을 보내는지는 고려하지 않는다."""
    unescaped = unquote(url_path)              # Go: url.PathUnescape
    cleaned = posixpath.normpath(unescaped)    # Go: path.Clean  ('?' 는 그냥 문자)
    match = NAMESPACE_PATH_RE.match(cleaned)
    if not match:
        return False, "네임스페이스 세그먼트 없음"
    extracted = match.group(2)
    if extracted != policy_namespace:
        return False, f"다른 네임스페이스({extracted})"
    return True, f"통과 (검증기가 본 네임스페이스: {extracted})"


def what_executor_requests(url_path: str) -> str:
    """실행기(client-go RequestURI → net/url.Parse)가 실제로 보내는 path."""
    split = urlsplit(url_path)                 # '?' 뒤는 query, '#' 뒤는 fragment
    return split.path or "/"


# ---------------------------------------------------------------------------
# 2) 안전한 검증 — URL 파서로 먼저 분리하고, 검증한 경로만 실행한다
# ---------------------------------------------------------------------------
def safe_is_allowed(url_path: str, policy_namespace: str):
    if not url_path.startswith("/"):
        return False, "상대 경로 거부 (/ 로 시작해야 함)"
    if "\\" in url_path:
        return False, "역슬래시 포함 거부"

    split = urlsplit(url_path)
    if split.scheme or split.netloc:
        return False, "절대 URL 거부"
    if split.fragment:
        return False, "fragment 거부"

    raw_path = split.path
    if ENCODED_CONTROL_RE.search(raw_path):
        return False, "경로에 인코딩된 ? / # / \\ 포함"

    decoded = unquote(raw_path)
    if "?" in decoded or "#" in decoded:
        return False, "디코딩 후 경로에 ? 또는 # 포함"

    cleaned = posixpath.normpath(decoded)
    if not cleaned.startswith("/") or cleaned.startswith("//"):
        return False, "정규화 후 경로가 // 로 시작"

    match = NAMESPACE_PATH_RE.match(cleaned)
    if not match:
        return False, "경로에 네임스페이스 세그먼트 없음"
    extracted = match.group(2)
    if extracted != policy_namespace:
        return False, f"다른 네임스페이스({extracted})"

    # 실행도 이 값으로만 한다: query 는 검증 대상이 아니므로 그대로 붙이되
    # 경로 판단은 cleaned 기준으로 끝낸 것.
    return True, f"통과 (검증·실행 경로: {cleaned})"


# ---------------------------------------------------------------------------
# 3) 비교 케이스 6종
# ---------------------------------------------------------------------------
POLICY_NS = "default"

CASES = [
    (
        "정상: 같은 네임스페이스 ConfigMap",
        "/api/v1/namespaces/default/configmaps",
        True,
        True,
    ),
    (
        "쿼리 decoy: 클러스터 전역 nodes",
        "/api/v1/nodes?x=/namespaces/default/",
        True,
        False,
    ),
    (
        "fragment decoy: 전 네임스페이스 secrets",
        "/api/v1/secrets#/namespaces/default/",
        True,
        False,
    ),
    (
        "교차 네임스페이스 직접 지정 — 이 형태는 검증에서도 거부",
        "/api/v1/namespaces/kube-system/secrets?x=/namespaces/default/",
        False,
        False,
    ),
    (
        "인코딩 decoy: %3F 로 '?' 숨김",
        "/api/v1/nodes%3Fx=/namespaces/default/",
        True,
        False,
    ),
    (
        "정상: 같은 네임스페이스 + 정상 쿼리(labelSelector)",
        "/api/v1/namespaces/default/configmaps?labelSelector=app%3Dweb",
        True,
        True,
    ),
]


def run_namespace_cases() -> int:
    failures = 0
    print("=" * 78)
    print(f"네임스페이스 검증 비교 (정책 네임스페이스: {POLICY_NS})")
    print("=" * 78)

    for title, url_path, expect_vuln, expect_safe in CASES:
        vuln_ok, vuln_msg = vulnerable_is_allowed(url_path, POLICY_NS)
        safe_ok, safe_msg = safe_is_allowed(url_path, POLICY_NS)
        actual_path = what_executor_requests(url_path)

        status = "PASS"
        if vuln_ok != expect_vuln or safe_ok != expect_safe:
            status = "FAIL"
            failures += 1

        print(f"\n[{status}] {title}")
        print(f"  urlPath        : {url_path}")
        print(f"  취약한 검증    : {'허용' if vuln_ok else '거부'} — {vuln_msg}")
        print(f"  실제 요청 경로 : {actual_path}")
        print(f"  안전한 검증    : {'허용' if safe_ok else '거부'} — {safe_msg}")
        print(f"  기대값         : 취약={'허용' if expect_vuln else '거부'} / "
              f"안전={'허용' if expect_safe else '거부'}")
        if vuln_ok and not safe_ok:
            print("  → 같은 입력을 취약한 검증은 통과시키고, 안전한 검증은 막습니다.")

    return failures


# ---------------------------------------------------------------------------
# 4) 부록: ?next= 오픈 리다이렉트 — 브라우저(WHATWG)와 urlsplit 의 해석 차이
# ---------------------------------------------------------------------------
REDIRECT_CASES = [
    # (입력, 브라우저가 실제로 향하는 호스트, 안전한 검증의 기대값)
    ("/dashboard", "good.com", True),
    ("//evil.com", "evil.com", False),
    ("/\\evil.com", "evil.com", False),
    ("https://evil.com\\@good.com/", "evil.com", False),
]


def naive_redirect_ok(target: str, allowed_host: str = "good.com") -> bool:
    """urlsplit 의 hostname 만 믿는 흔한 검증 (역슬래시를 놓친다)."""
    return urlsplit(target).hostname == allowed_host


def safe_redirect_target(target: str) -> bool:
    if "\\" in target:
        return False
    if not target.startswith("/") or target.startswith("//"):
        return False
    split = urlsplit(target)
    if split.scheme or split.netloc:
        return False
    if "#" in target:
        return False
    return True


def run_redirect_cases() -> int:
    failures = 0
    print("\n" + "=" * 78)
    print("부록: ?next= 오픈 리다이렉트 (브라우저는 '\\' 를 '/' 로 정규화)")
    print("=" * 78)

    for target, browser_host, expect_safe in REDIRECT_CASES:
        safe_ok = safe_redirect_target(target)
        naive_ok = naive_redirect_ok(target)
        status = "PASS" if safe_ok == expect_safe else "FAIL"
        if status == "FAIL":
            failures += 1
        print(f"\n[{status}] next={target!r}")
        print(f"  브라우저 도착 호스트 : {browser_host}")
        print(f"  urlsplit().hostname  : {urlsplit(target).hostname!r}")
        print(f"  hostname만 보는 검증  : {'허용' if naive_ok else '거부'}")
        print(f"  안전한 검증          : {'허용' if safe_ok else '거부'} "
              f"(기대={'허용' if expect_safe else '거부'})")

    return failures


def main() -> int:
    failures = run_namespace_cases()
    failures += run_redirect_cases()

    print("\n" + "-" * 78)
    if failures:
        print(f"실패 {failures}건 — 기대값과 다른 판정이 있습니다.")
        return 1
    print("모든 케이스가 기대값과 일치합니다.")
    print("핵심: URL 은 URL 파서로 먼저 파싱하고, 검증한 그 경로로만 실행합니다.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(2)
