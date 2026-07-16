#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ASSET_ROOT="${SCRIPT_DIR:h}"
REPO_ROOT="${ASSET_ROOT:h:h:h}"
WORKSPACE="$REPO_ROOT/TimeNest.xcworkspace"
APP_BUNDLE_ID="com.song.TimeNest"
DERIVED_DATA="${DERIVED_DATA:-/tmp/TimeNestAppStoreScreenshots}"
CAPTURE_WIDGET="${CAPTURE_WIDGET:-1}"
RESET_SIMULATORS="${RESET_SIMULATORS:-0}"

if [[ -z "${PHONE_UDID:-}" || -z "${IPAD_UDID:-}" ]]; then
  echo "Set PHONE_UDID and IPAD_UDID to dedicated bootable Simulator device IDs." >&2
  exit 2
fi

typeset -a SCENES
typeset -a FILES
SCENES=(
  month_view
  week_view
  day_view
  event_editor
  shift_record
  work_record
  holiday_view
  shared_calendar
  shared_calendar_switcher
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
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100
}

find_app() {
  find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name 'TimeNest.app' -print -quit
}

capture_app_scenes() {
  local udid="$1"
  local platform="$2"
  local output="$ASSET_ROOT/$platform/raw"
  local index
  mkdir -p "$output"
  xcrun simctl install "$udid" "$APP_PATH"

  for index in {1..9}; do
    xcrun simctl launch --terminate-running-process "$udid" "$APP_BUNDLE_ID" \
      --timenest-screenshot-scene "$SCENES[$index]" >/dev/null
    sleep 2
    xcrun simctl io "$udid" screenshot --type=png "$output/$FILES[$index]" >/dev/null
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
  xcrun simctl io "$udid" screenshot --type=png "$output" >/dev/null
}

prepare_device "$PHONE_UDID"
prepare_device "$IPAD_UDID"

xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme TimeNest \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$PHONE_UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$(find_app)"
if [[ -z "$APP_PATH" ]]; then
  echo "TimeNest.app was not found under $DERIVED_DATA." >&2
  exit 3
fi

capture_app_scenes "$PHONE_UDID" iPhone
capture_app_scenes "$IPAD_UDID" iPad

if [[ "$CAPTURE_WIDGET" == "1" ]]; then
  capture_widget "$PHONE_UDID" iPhone
  capture_widget "$IPAD_UDID" iPad
fi

echo "Raw captures written to $ASSET_ROOT/{iPhone,iPad}/raw"
