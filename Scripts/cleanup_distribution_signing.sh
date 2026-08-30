#!/bin/bash
set -u

runner_temp="${RUNNER_TEMP:-}"
profiles_directory="${HOME:-}/Library/MobileDevice/Provisioning Profiles"
signing_directory="$runner_temp/distribution-signing"
installed_profiles_file="$signing_directory/installed-profiles.txt"
keychain_path="$runner_temp/timenest-signing.keychain-db"

if [[ -z "$runner_temp" || "$runner_temp" != /* || "$runner_temp" = "/" ]]; then
  echo "RUNNER_TEMP must be a non-root absolute path; signing cleanup was skipped." >&2
  exit 0
fi

if [[ -n "${HOME:-}" && -f "$installed_profiles_file" ]]; then
  while IFS= read -r profile; do
    case "$profile" in
      "$profiles_directory"/*.mobileprovision) rm -f -- "$profile" ;;
      *) echo "Refusing to remove unexpected provisioning profile path: $profile" >&2 ;;
    esac
  done < "$installed_profiles_file"
fi

security delete-keychain "$keychain_path" 2>/dev/null || true

rm -f -- \
  "$signing_directory/distribution.p12" \
  "$signing_directory/installed-profiles.txt" \
  "$signing_directory/com.song.TimeNest.mobileprovision" \
  "$signing_directory/com.song.TimeNest.plist" \
  "$signing_directory/com.song.TimeNest.TimeNestWidgetExtension.mobileprovision" \
  "$signing_directory/com.song.TimeNest.TimeNestWidgetExtension.plist"
rmdir -- "$signing_directory" 2>/dev/null || true
