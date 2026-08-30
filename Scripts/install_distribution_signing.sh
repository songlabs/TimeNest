#!/bin/bash
set -euo pipefail

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_ENV:?GITHUB_ENV is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${APPLE_DISTRIBUTION_P12_BASE64:?APPLE_DISTRIBUTION_P12_BASE64 is required}"
: "${APPLE_DISTRIBUTION_P12_PASSWORD:?APPLE_DISTRIBUTION_P12_PASSWORD is required}"

profiles=(
  "PROFILE_TIMENEST_BASE64|com.song.TimeNest|TimeNest App Store|main"
  "PROFILE_TIMENEST_WIDGET_BASE64|com.song.TimeNest.TimeNestWidgetExtension|TimeNest Widget App Store|widget"
)

signing_directory="$RUNNER_TEMP/distribution-signing"
keychain_path="$RUNNER_TEMP/timenest-signing.keychain-db"
keychain_password="$(openssl rand -hex 32)"
p12_path="$signing_directory/distribution.p12"
installed_profiles_file="$signing_directory/installed-profiles.txt"
profiles_directory="$HOME/Library/MobileDevice/Provisioning Profiles"

mkdir -p "$signing_directory" "$profiles_directory"
chmod 700 "$signing_directory"
printf '%s' "$APPLE_DISTRIBUTION_P12_BASE64" | base64 --decode > "$p12_path"
chmod 600 "$p12_path"

security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$p12_path" -k "$keychain_path" -P "$APPLE_DISTRIBUTION_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain_path" >/dev/null
security list-keychains -d user -s "$keychain_path" login.keychain-db

identities="$(security find-identity -v -p codesigning "$keychain_path")"
printf '%s\n' "$identities"
distribution_identity_count="$(printf '%s\n' "$identities" | grep -c 'Apple Distribution:' || true)"
team_distribution_identity_count="$(printf '%s\n' "$identities" | grep -Ec "Apple Distribution:.*\\($APPLE_TEAM_ID\\)" || true)"
test "$distribution_identity_count" -eq 1 || {
  echo "Expected exactly one valid Apple Distribution identity, found $distribution_identity_count." >&2
  exit 1
}
test "$team_distribution_identity_count" -eq 1 || {
  echo "The Apple Distribution identity does not belong to team $APPLE_TEAM_ID." >&2
  exit 1
}

read_plist() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1"
}

assert_plist_value() {
  local plist=$1 key_path=$2 expected=$3 description=$4
  local actual
  actual="$(read_plist "$plist" "$key_path" 2>/dev/null || true)"
  test "$actual" = "$expected" || {
    echo "Profile validation failed for $description." >&2
    exit 1
  }
}

assert_plist_array_contains() {
  local plist=$1 key_path=$2 expected=$3 description=$4
  local values
  values="$(read_plist "$plist" "$key_path" 2>/dev/null || true)"
  printf '%s\n' "$values" | grep -Fq "$expected" || {
    echo "Profile validation failed for $description." >&2
    exit 1
  }
}

assert_plist_array_contains_any() {
  local plist=$1 key_path=$2 first_expected=$3 second_expected=$4 description=$5
  local values
  values="$(read_plist "$plist" "$key_path" 2>/dev/null || true)"
  if ! printf '%s\n' "$values" | grep -Fq "$first_expected" && \
     ! printf '%s\n' "$values" | grep -Fq "$second_expected"; then
    echo "Profile validation failed for $description." >&2
    exit 1
  fi
}

for profile_definition in "${profiles[@]}"; do
  IFS='|' read -r secret_name expected_bundle_id expected_name target_kind <<< "$profile_definition"
  profile_base64="${!secret_name:-}"
  test -n "$profile_base64" || { echo "Missing $secret_name" >&2; exit 1; }

  encoded_profile="$signing_directory/$expected_bundle_id.mobileprovision"
  decoded_profile="$signing_directory/$expected_bundle_id.plist"
  printf '%s' "$profile_base64" | base64 --decode > "$encoded_profile"
  security cms -D -i "$encoded_profile" > "$decoded_profile"

  uuid="$(read_plist "$decoded_profile" UUID)"
  name="$(read_plist "$decoded_profile" Name)"
  team_identifier="$(read_plist "$decoded_profile" TeamIdentifier:0)"
  application_identifier="$(read_plist "$decoded_profile" Entitlements:application-identifier)"
  expiration_date="$(read_plist "$decoded_profile" ExpirationDate)"
  get_task_allow="$(read_plist "$decoded_profile" Entitlements:get-task-allow 2>/dev/null || printf 'false')"
  beta_reports_active="$(read_plist "$decoded_profile" Entitlements:beta-reports-active 2>/dev/null || printf 'false')"

  [[ "$uuid" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] || {
    echo "Invalid profile UUID for $expected_bundle_id." >&2
    exit 1
  }
  test "$name" = "$expected_name" || { echo "Profile for $expected_bundle_id must be named '$expected_name'." >&2; exit 1; }
  test "$team_identifier" = "$APPLE_TEAM_ID" || { echo "Wrong team in profile $uuid." >&2; exit 1; }
  test "$application_identifier" = "$APPLE_TEAM_ID.$expected_bundle_id" || { echo "Wrong Bundle ID in profile $uuid." >&2; exit 1; }
  test "$get_task_allow" = "false" || { echo "Development profile rejected for $expected_bundle_id." >&2; exit 1; }
  test "$beta_reports_active" = "true" || { echo "Non-App-Store profile rejected for $expected_bundle_id." >&2; exit 1; }
  ! /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$decoded_profile" >/dev/null 2>&1 || {
    echo "Development or Ad Hoc profile rejected for $expected_bundle_id." >&2
    exit 1
  }
  ! /usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$decoded_profile" >/dev/null 2>&1 || {
    echo "Enterprise profile rejected for $expected_bundle_id." >&2
    exit 1
  }
  ruby -rtime -e 'exit(Time.parse(ARGV.fetch(0)) > Time.now ? 0 : 1)' "$expiration_date" || {
    echo "Expired profile rejected for $expected_bundle_id." >&2
    exit 1
  }

  assert_plist_array_contains "$decoded_profile" "Entitlements:com.apple.security.application-groups" \
    "group.com.songlabs.timenest" "$expected_bundle_id App Group entitlement"

  if [[ "$target_kind" = "main" ]]; then
    assert_plist_array_contains "$decoded_profile" "Entitlements:com.apple.developer.icloud-container-identifiers" \
      "iCloud.com.song.TimeNest" "$expected_bundle_id iCloud container entitlement"
    assert_plist_array_contains_any "$decoded_profile" "Entitlements:com.apple.developer.icloud-services" \
      "CloudKit" "*" "$expected_bundle_id CloudKit entitlement"
    assert_plist_array_contains "$decoded_profile" "Entitlements:com.apple.developer.icloud-container-environment" \
      "Production" "$expected_bundle_id production CloudKit environment"
    assert_plist_array_contains "$decoded_profile" "Entitlements:com.apple.developer.icloud-extended-share-access" \
      "InProcessOneTimeLinks" "$expected_bundle_id iCloud extended share entitlement"
    assert_plist_value "$decoded_profile" "Entitlements:com.apple.developer.weatherkit" \
      "true" "$expected_bundle_id WeatherKit entitlement"
  fi

  installed_profile="$profiles_directory/$uuid.mobileprovision"
  cp "$encoded_profile" "$installed_profile"
  printf '%s\n' "$installed_profile" >> "$installed_profiles_file"
  printf 'Profile UUID: %s\nBundle ID: %s\nExpiration: %s\nSigning type: App Store distribution\n\n' \
    "$uuid" "$expected_bundle_id" "$expiration_date"
done

{
  echo "SIGNING_KEYCHAIN_PATH=$keychain_path"
  echo "SIGNING_P12_PATH=$p12_path"
  echo "INSTALLED_PROFILES_FILE=$installed_profiles_file"
} >> "$GITHUB_ENV"
