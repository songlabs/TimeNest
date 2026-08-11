#!/bin/bash
set -euo pipefail

archive_path=${1:?Usage: verify_distribution_archive.sh ARCHIVE_PATH}
app="$archive_path/Products/Applications/TimeNest.app"
widget="$app/PlugIns/TimeNestWidgetExtension.appex"

test -d "$app"
test -d "$widget"
codesign --verify --deep --strict --verbose=2 "$app"
test -f "$app/embedded.mobileprovision"
test -f "$widget/embedded.mobileprovision"

app_entitlements=$(mktemp)
widget_entitlements=$(mktemp)
trap 'rm -f "$app_entitlements" "$widget_entitlements"' EXIT
codesign -d --entitlements :- "$app" > "$app_entitlements"
codesign -d --entitlements :- "$widget" > "$widget_entitlements"

assert_plist_value() {
  local plist=$1 key_path=$2 expected=$3
  actual=$(/usr/libexec/PlistBuddy -c "Print :$key_path" "$plist")
  test "$actual" = "$expected" || {
    echo "Unexpected entitlement $key_path: expected '$expected', got '$actual'" >&2
    exit 1
  }
}

assert_plist_value "$app_entitlements" "com.apple.security.application-groups:0" "group.com.songlabs.timenest"
assert_plist_value "$app_entitlements" "com.apple.developer.icloud-container-identifiers:0" "iCloud.com.song.TimeNest"
assert_plist_value "$app_entitlements" "com.apple.developer.icloud-services:0" "CloudKit"
assert_plist_value "$app_entitlements" "com.apple.developer.icloud-container-environment" "Production"
assert_plist_value "$app_entitlements" "com.apple.developer.weatherkit" "true"
assert_plist_value "$widget_entitlements" "com.apple.security.application-groups:0" "group.com.songlabs.timenest"

echo "Archive signatures, provisioning profiles, and required entitlements are valid."
