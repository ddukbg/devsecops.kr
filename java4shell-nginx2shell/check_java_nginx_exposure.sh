#!/usr/bin/env bash
# Java4Shell (CVE-2026-114938) / NGINX2Shell (CVE-2026-123007, CVE-2026-123633)
# 발동 조건 확인용 읽기 전용 스크립트. 시스템을 변경하지 않는다.
set -u

echo "== Java4Shell =="
if command -v java >/dev/null 2>&1; then
  java -version 2>&1 | sed 's/^/  /'
  if command -v lscpu >/dev/null 2>&1 && lscpu | grep -q avx512_vbmi; then
    echo "  [조건] CPU: avx512_vbmi 지원"
  else
    echo "  [조건] CPU: avx512_vbmi 미지원 (Java4Shell 발동 조건 아님)"
  fi
  use_avx="$(java -XX:+PrintFlagsFinal -version 2>/dev/null | awk '/UseAVX /{print $NF}' | head -n1)"
  if [ "${use_avx:-}" = "3" ]; then
    echo "  [조건] JVM UseAVX=3 (AVX-512 사용)"
  elif [ -n "${use_avx:-}" ]; then
    echo "  [조건] JVM UseAVX=${use_avx}"
  else
    echo "  [정보] UseAVX 값을 읽지 못했습니다."
  fi
  echo "  [판단] Java 17-27 + x86-64 + avx512_vbmi 이면 패치 대상. Java 8/11, ARM64는 비해당."
else
  echo "  java 명령을 찾을 수 없습니다."
fi

echo
echo "== NGINX2Shell =="
if command -v nginx >/dev/null 2>&1; then
  nginx -v 2>&1 | sed 's/^/  /'
  if nginx -T 2>/dev/null | grep -q 'http2'; then
    echo "  [조건] 설정에 http2 지시어가 있습니다. 적용 중인 server/listen 블록을 직접 확인하세요."
  else
    echo "  [조건] 설정에서 http2 지시어를 찾지 못했습니다. (미적용이면 NGINX2Shell 비해당)"
  fi
  echo "  [판단] 1.21.4-1.31.9 + HTTP/2 활성 + 리버스 프록시 커넥션 재사용이면 패치 대상."
else
  echo "  nginx 명령을 찾을 수 없습니다."
fi

echo
echo "고정 버전: OpenJDK 17.0.21.1 / 21.0.13.1 등, NGINX 1.31.10 / 1.30.8"
echo "이 스크립트는 점검 보조용입니다. 패치 판단은 소속 조직의 정책을 따르세요."
