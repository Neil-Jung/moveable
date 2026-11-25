#!/bin/zsh
# Moveable.app 빌드 스크립트
#   ./build.sh            빌드 후 ./Moveable.app 을 교체하고 실행
#   ./build.sh --release  dist/Moveable.zip 만 만든다 (실행 중인 앱은 건드리지 않음)
set -euo pipefail
cd "$(dirname "$0")"

RELEASE=0
[[ "${1:-}" == "--release" ]] && RELEASE=1

# Xcode 라이선스 동의 없이도 빌드되도록 Command Line Tools 를 우선 사용
if [[ -z "${DEVELOPER_DIR:-}" && -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

APP="Moveable.app"
WORK=".build-tmp"
TMP="$WORK/$APP"
rm -rf "$WORK"
mkdir -p "$TMP/Contents/MacOS"
cp Info.plist "$TMP/Contents/Info.plist"

# Apple Silicon + Intel 유니버설 바이너리
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macosx13.0" \
    -framework AppKit -framework ApplicationServices -framework ServiceManagement \
    Sources/main.swift -o "$WORK/Moveable-$arch"
done
lipo -create "$WORK/Moveable-arm64" "$WORK/Moveable-x86_64" -output "$TMP/Contents/MacOS/Moveable"

xattr -cr "$TMP"
codesign --force --sign - --identifier local.moveable.app "$TMP"

if (( RELEASE )); then
  mkdir -p dist
  rm -f dist/Moveable.zip
  ditto -c -k --norsrc --noextattr --noqtn --keepParent "$TMP" dist/Moveable.zip
  rm -rf "$WORK"
  echo "릴리스 파일: $(pwd)/dist/Moveable.zip"
  exit 0
fi

# 빌드가 성공했을 때만 기존 앱을 교체
pkill -f "$APP/Contents/MacOS/Moveable" 2>/dev/null || true
rm -rf "$APP"
mv "$TMP" "$APP"
rm -rf "$WORK"
open "$APP"
echo "빌드 완료 및 실행: $(pwd)/$APP"
echo "※ 다시 빌드하면 시스템 설정 > 손쉬운 사용 에서 Moveable 권한을 다시 켜야 합니다."
