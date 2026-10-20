#!/usr/bin/env bash
# 배포 빌드: 유니버설 바이너리 → 서명 → notarization → staple → zip / dmg
#
# 필요한 환경변수
#   SIGN_IDENTITY   "Developer ID Application: 이름 (TEAMID)"  (없으면 ad-hoc 서명)
#   NOTARY_PROFILE  xcrun notarytool 에 등록한 키체인 프로파일 이름
#   BUNDLE_ID       앱 번들 아이디 (기본값 com.jhpark.commandcode-usage-bar)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Command Code Usage Bar"
APP="$ROOT/dist/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
ENTITLEMENTS="$ROOT/Resources/Entitlements/developerid.entitlements"
BUNDLE_ID="${BUNDLE_ID:-com.jhpark.commandcode-usage-bar}"
BASE="${APP_NAME}-${VERSION}-universal"

"$ROOT/scripts/build-app.sh" --universal

echo "▸ 배포용 서명"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" "$APP"
else
  echo "⚠︎ SIGN_IDENTITY 가 없어 ad-hoc 서명으로 진행합니다 (notarization 불가)" >&2
  codesign --force --options runtime --sign - "$APP"
fi

echo "▸ 검증"
codesign --verify --deep --strict --verbose=2 "$APP" || true
if command -v spctl >/dev/null 2>&1 && [[ -n "${SIGN_IDENTITY:-}" ]]; then
  spctl --assess --type execute --verbose=2 "$APP" || true
fi
echo "  아키텍처: $(lipo -archs "$APP/Contents/MacOS/CommandCodeUsageBar")"

ZIP="$ROOT/dist/${BASE}.zip"
DMG="$ROOT/dist/${BASE}.dmg"

echo "▸ zip 생성"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "▸ notarization 요청 (기다리는 동안 Apple에 제출)"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "▸ staple"
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
else
  echo "⚠︎ NOTARY_PROFILE 이 없어 notarization 을 건너뜁니다" >&2
fi

echo "▸ dmg 생성"
rm -f "$DMG"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/설치 안내.txt" <<'NOTE'
Command Code Usage Bar 설치 안내

1. 이 dmg 의 "Command Code Usage Bar" 를 Applications 폴더로 옮깁니다.
2. Applications 에 옮긴 앱을 실행합니다.
3. 첫 실행 때 보안 경고가 뜨면 "오른쪽 클릭 → 열기" 를 누릅니다.
4. 앱은 macOS 26 이상이 필요합니다.

사용량 데이터(Command Code 계정)는 이 기기 안에만 저장됩니다.
NOTE
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "✓ 배포 준비 완료"
echo "  $ZIP"
echo "  $DMG"
echo "  (버전 $VERSION / 빌드 $BUILD / 번들아이디 $BUNDLE_ID)"
