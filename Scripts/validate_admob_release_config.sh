#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
    exit 0
fi

case "${PLATFORM_NAME:-}${EFFECTIVE_PLATFORM_NAME:-}${SDK_NAME:-}" in
    *iphonesimulator*)
        exit 0
        ;;
esac

fail() {
    echo "error: $1" >&2
    exit 1
}

ads_enabled="${TIMENEST_ADS_ENABLED:-}"
app_id="${TIMENEST_ADMOB_APP_ID:-}"
banner_id="${TIMENEST_ADMOB_BANNER_UNIT_ID:-}"

[ "$ads_enabled" = "YES" ] || fail "Release advertising must be enabled (TIMENEST_ADS_ENABLED=YES)."

[ "$app_id" != "ca-app-pub-3940256099942544~1458002511" ] || \
    fail "Release cannot use Google's test AdMob App ID."
[ "$banner_id" != "ca-app-pub-3940256099942544/2435281174" ] || \
    fail "Release cannot use Google's test AdMob Banner Unit ID."

printf '%s' "$app_id" | grep -Eq '^ca-app-pub-[0-9]{16}~[0-9]{10}$' || \
    fail "Set TIMENEST_ADMOB_APP_ID to the production AdMob App ID. Empty and placeholder values are rejected."
printf '%s' "$banner_id" | grep -Eq '^ca-app-pub-[0-9]{16}/[0-9]{10}$' || \
    fail "Set TIMENEST_ADMOB_BANNER_UNIT_ID to the production Banner Unit ID. Empty and placeholder values are rejected."
