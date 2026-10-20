#!/usr/bin/env bash
# Command Code Usage Bar 를 .app 번들로 빌드한다.
#
#   ./scripts/build-app.sh              # 현재 아키텍처(로컬)
#   ./scripts/build-app.sh --run        # 빌드 후 실행
#   ./scripts/build-app.sh --universal  # arm64 + x86_64 유니버설(배포용)
#   ./scripts/build-app.sh --sandbox    # Mac App Store 용(샌드박스 엔티틀먼트)
#
# Xcode 프로젝트 없이 SwiftPM 으로 빌드하고, Info.plist 로 .app 번들을 직접 조립한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Command Code Usage Bar"
APP="$ROOT/dist/$APP_NAME.app"
RUN_APP=false
SANDBOX=false
UNIVERSAL=false

for arg in "$@"; do
  case "$arg" in
    --run) RUN_APP=true ;;
    --sandbox) SANDBOX=true ;;
    --universal) UNIVERSAL=true ;;
    *) echo "알 수 없는 옵션: $arg" >&2; exit 2 ;;
  esac
done

if [[ "$SANDBOX" == "true" ]]; then
  ENTITLEMENTS="$ROOT/Resources/Entitlements/sandboxed.entitlements"
  SIGN_ARGS=(--force --options runtime --sign -)
else
  ENTITLEMENTS="$ROOT/Resources/Entitlements/developerid.entitlements"
  SIGN_ARGS=(--force --sign -)
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "▸ swift build -c release"
if [[ "$UNIVERSAL" == "true" ]]; then
  # SwiftPM 의 멀티 아크 빌드는 xcbuild(전체 Xcode) 를 요구하므로
  # 아키텍처별로 따로 빌드한 뒤 lipo 로 합친다.
  swift build -c release --arch arm64
  swift build -c release --arch x86_64
  lipo -create \
    "$ROOT/.build/arm64-apple-macosx/release/CommandCodeUsageBar" \
    "$ROOT/.build/x86_64-apple-macosx/release/CommandCodeUsageBar" \
    -output "$STAGE/CommandCodeUsageBar"
  echo "  유니버설: $(lipo -archs "$STAGE/CommandCodeUsageBar")"
else
  swift build -c release
  BIN_DIR="$(swift build -c release --show-bin-path)"
  cp "$BIN_DIR/CommandCodeUsageBar" "$STAGE/CommandCodeUsageBar"
fi

echo "▸ 앱 번들 조립"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$STAGE/CommandCodeUsageBar" "$APP/Contents/MacOS/CommandCodeUsageBar"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/PrivacyInfo.xcprivacy" "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
chmod +x "$APP/Contents/MacOS/CommandCodeUsageBar"

echo "▸ 코드 서명"
if command -v codesign >/dev/null 2>&1; then
  if codesign "${SIGN_ARGS[@]}" --entitlements "$ENTITLEMENTS" "$APP" >/dev/null 2>&1; then
    echo "  서명 완료 ($ENTITLEMENTS)"
  else
    echo "⚠︎ 서명에 실패했습니다 (실행 시 보안 경고가 뜰 수 있습니다)" >&2
  fi
fi

echo "✓ 빌드 완료: $APP"

if [[ "$RUN_APP" == "true" ]]; then
  open "$APP"
  echo "▸ 실행했습니다."
fi
