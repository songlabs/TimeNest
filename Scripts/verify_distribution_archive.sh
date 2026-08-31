#!/bin/bash
set -euo pipefail

archive_path=${1:?Usage: verify_distribution_archive.sh ARCHIVE_PATH}
app="$archive_path/Products/Applications/TimeNest.app"
widget="$app/PlugIns/TimeNestWidgetExtension.appex"
script_dir=$(cd "$(dirname "$0")" && pwd)
source_entitlements="$script_dir/../TimeNest/TimeNest.entitlements"
firebase_config="$app/GoogleService-Info.plist"

test -d "$app"
test -d "$widget"
codesign --verify --deep --strict --verbose=2 "$app"
test -f "$app/embedded.mobileprovision"
test -f "$widget/embedded.mobileprovision"
test -f "$source_entitlements"
test -s "$firebase_config"
test ! -e "$widget/GoogleService-Info.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$firebase_config")" = "com.song.TimeNest"

app_entitlements=$(mktemp)
widget_entitlements=$(mktemp)
app_profile=$(mktemp)
trap 'rm -f "$app_entitlements" "$widget_entitlements" "$app_profile"' EXIT
codesign -d --entitlements :- "$app" > "$app_entitlements"
codesign -d --entitlements :- "$widget" > "$widget_entitlements"
security cms -D -i "$app/embedded.mobileprovision" > "$app_profile"

assert_plist_value() {
  local plist=$1 key_path=$2 expected=$3
  actual=$(/usr/libexec/PlistBuddy -c "Print :$key_path" "$plist")
  test "$actual" = "$expected" || {
    echo "Unexpected entitlement $key_path: expected '$expected', got '$actual'" >&2
    exit 1
  }
}

assert_plist_value "$app_entitlements" "com.apple.security.application-groups:0" "group.com.songlabs.timenest"
assert_plist_value "$source_entitlements" "com.apple.developer.devicecheck.appattest-environment" "production"
assert_plist_value "$app_profile" "Entitlements:com.apple.developer.devicecheck.appattest-environment" "production"
assert_plist_value "$app_entitlements" "com.apple.developer.devicecheck.appattest-environment" "production"
assert_plist_value "$app_entitlements" "com.apple.developer.icloud-container-identifiers:0" "iCloud.com.song.TimeNest"
assert_plist_value "$app_entitlements" "com.apple.developer.icloud-services:0" "CloudKit"
assert_plist_value "$app_entitlements" "com.apple.developer.icloud-container-environment" "Production"
assert_plist_value "$app_entitlements" "com.apple.developer.icloud-extended-share-access:0" "InProcessOneTimeLinks"
assert_plist_value "$app_entitlements" "com.apple.developer.weatherkit" "true"
assert_plist_value "$widget_entitlements" "com.apple.security.application-groups:0" "group.com.songlabs.timenest"
if /usr/libexec/PlistBuddy \
  -c "Print :com.apple.developer.devicecheck.appattest-environment" \
  "$widget_entitlements" >/dev/null 2>&1; then
  echo "Widget must not contain the App Attest entitlement." >&2
  exit 1
fi

echo "Archive signatures, provisioning profiles, and required entitlements are valid."
