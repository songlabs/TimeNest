#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$ASSET_ROOT/../../.." && pwd)"
WORKSPACE="$REPO_ROOT/TimeNest.xcworkspace"
APP_BUNDLE_ID="com.song.TimeNest"
DERIVED_DATA="${DERIVED_DATA:-/tmp/TimeNestAppStoreScreenshots}"
CAPTURE_WIDGET="${CAPTURE_WIDGET:-1}"
RESET_SIMULATORS="${RESET_SIMULATORS:-0}"
PLATFORM="$(printf '%s' "${1:-all}" | tr '[:upper:]' '[:lower:]')"

case "$PLATFORM" in
  iphone|ipad|all) ;;
  *)
    echo "Usage: $0 [iphone|ipad|all]" >&2
    exit 2
    ;;
esac

if [[ "$PLATFORM" == "iphone" || "$PLATFORM" == "all" ]]; then
  if [[ -z "${PHONE_UDID:-}" ]]; then
    echo "Set PHONE_UDID to a dedicated bootable iPhone Simulator device ID." >&2
    exit 2
  fi
fi

if [[ "$PLATFORM" == "ipad" || "$PLATFORM" == "all" ]]; then
  if [[ -z "${IPAD_UDID:-}" ]]; then
    echo "Set IPAD_UDID to a dedicated bootable iPad Simulator device ID." >&2
    exit 2
  fi
fi

SCENES=(
  month_view
  week_view
  day_view
  event_editor
  shift_record
  work_record
  holiday_view
  shared_month
  shared_switcher
)
FILES=(
  01_month_overview.png
  02_week_timeline.png
  03_day_timeline.png
  04_event_editor.png
  05_shift_management.png
  06_work_record.png
  07_holidays.png
  08_shared_calendar.png
  09_calendar_switcher.png
)

prepare_device() {
  local udid="$1"
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  if [[ "$RESET_SIMULATORS" == "1" ]]; then
    xcrun simctl erase "$udid"
  fi
  xcrun simctl boot "$udid"
  open -g -a Simulator --args -CurrentDeviceUDID "$udid"
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl spawn "$udid" defaults write NSGlobalDomain AppleLanguages -array ja
  xcrun simctl spawn "$udid" defaults write NSGlobalDomain AppleLocale -string ja_JP
  xcrun simctl shutdown "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl status_bar "$udid" override \
    --time 9:41 \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4
}

find_app() {
  find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" \
    -maxdepth 1 \
    -name 'TimeNest.app' \
    -print \
    -quit
}

expected_size() {
  local platform="$1"
  python3 -c \
    'import json, sys; data=json.load(open(sys.argv[1], encoding="utf-8")); p=data["platforms"][sys.argv[2]]; print(p["width"], p["height"])' \
    "$ASSET_ROOT/manifest.json" \
    "$platform"
}

verify_capture_size() {
  local file="$1"
  local platform="$2"
  local expected_width expected_height actual_width actual_height
  read -r expected_width expected_height <<<"$(expected_size "$platform")"
  actual_width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')"
  actual_height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')"
  if [[ "$actual_width" != "$expected_width" || "$actual_height" != "$expected_height" ]]; then
    echo "$file has ${actual_width}x${actual_height}; expected ${expected_width}x${expected_height}." >&2
    exit 4
  fi
}

capture_app_scenes() {
  local udid="$1"
  local platform="$2"
  local output="$ASSET_ROOT/$platform/raw"
  local index destination
  mkdir -p "$output"
  xcrun simctl install "$udid" "$APP_PATH"

  for index in "${!SCENES[@]}"; do
    destination="$output/${FILES[$index]}"
    xcrun simctl launch --terminate-running-process "$udid" "$APP_BUNDLE_ID" \
      --timenest-screenshot-scene "${SCENES[$index]}" >/dev/null
    sleep 2
    xcrun simctl io "$udid" screenshot --type=png "$destination" >/dev/null
    verify_capture_size "$destination" "$platform"
  done
}

capture_widget() {
  local udid="$1"
  local platform="$2"
  local output="$ASSET_ROOT/$platform/raw/10_widget.png"

  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme TimeNestScreenshotUITests \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:TimeNestScreenshotUITests/WidgetSetupUITests/testInstallTimeNestWidget \
    test

  xcrun simctl uninstall "$udid" com.song.TimeNestScreenshotUITests.xctrunner >/dev/null 2>&1 || true
  sleep 2
  xcrun simctl status_bar "$udid" override \
    --time 9:41 \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4
  xcrun simctl io "$udid" screenshot --type=png "$output" >/dev/null
  verify_capture_size "$output" "$platform"
}

if [[ "$PLATFORM" == "iphone" || "$PLATFORM" == "all" ]]; then
  prepare_device "$PHONE_UDID"
fi
if [[ "$PLATFORM" == "ipad" || "$PLATFORM" == "all" ]]; then
  prepare_device "$IPAD_UDID"
fi

if [[ "$PLATFORM" == "ipad" ]]; then
  BUILD_UDID="$IPAD_UDID"
else
  BUILD_UDID="$PHONE_UDID"
fi

xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme TimeNest \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$BUILD_UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$(find_app)"
if [[ -z "$APP_PATH" ]]; then
  echo "TimeNest.app was not found under $DERIVED_DATA." >&2
  exit 3
fi

if [[ "$PLATFORM" == "iphone" || "$PLATFORM" == "all" ]]; then
  capture_app_scenes "$PHONE_UDID" iPhone
  if [[ "$CAPTURE_WIDGET" == "1" ]]; then
    capture_widget "$PHONE_UDID" iPhone
  fi
fi

if [[ "$PLATFORM" == "ipad" || "$PLATFORM" == "all" ]]; then
  capture_app_scenes "$IPAD_UDID" iPad
  if [[ "$CAPTURE_WIDGET" == "1" ]]; then
    capture_widget "$IPAD_UDID" iPad
  fi
fi

echo "Raw $PLATFORM captures written under $ASSET_ROOT."
