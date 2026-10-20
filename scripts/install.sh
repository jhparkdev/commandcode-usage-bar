#!/usr/bin/env bash
# 빌드된 앱을 ~/Applications 에 설치하고 로그인 시 자동 실행을 설정한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Command Code Usage Bar"
SOURCE="$ROOT/dist/$APP_NAME.app"
TARGET_DIR="$HOME/Applications"
TARGET="$TARGET_DIR/$APP_NAME.app"
AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT="$AGENT_DIR/com.jhpark.commandcode-usage-bar.plist"

if [[ ! -d "$SOURCE" ]]; then
  echo "먼저 scripts/build-app.sh 를 실행하세요." >&2
  exit 1
fi

echo "▸ $TARGET 으로 설치"
mkdir -p "$TARGET_DIR"
rm -rf "$TARGET"
cp -R "$SOURCE" "$TARGET"

if [[ "${1:-}" == "--no-launch-agent" ]]; then
  echo "✓ 설치 완료 (자동 실행은 앱 설정에서 켜세요)"
  exit 0
fi

echo "▸ 로그인 시 자동 실행 등록"
mkdir -p "$AGENT_DIR"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.jhpark.commandcode-usage-bar</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-a</string>
    <string>$TARGET</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>ProcessType</key>
  <string>Interactive</string>
</dict>
</plist>
PLIST

echo "✓ 설치 완료: $TARGET"
echo "  (자동 실행 비활성화: launchctl unload \"$AGENT\")"
