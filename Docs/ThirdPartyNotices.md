# TimeNest Third-Party Notices

This inventory is based on both checked-in `Package.resolved` files as of 2026-06-23. They resolve the same two Google Swift Package Manager wrapper repositories. Recheck this document whenever package versions change.

## Google Mobile Ads

- Product/module: `GoogleMobileAds`
- Resolved wrapper version: `13.5.0`
- Repository: https://github.com/googleads/swift-package-manager-google-mobile-ads
- Resolved revision: `166a2dcff33c893b22e4bfccbbdd0ed00a248c24`
- Wrapper license: Apache License 2.0
- Copyright notice: Copyright 2021 Google LLC
- License text: https://github.com/googleads/swift-package-manager-google-mobile-ads/blob/13.5.0/LICENSE

The wrapper package downloads Google's precompiled Google Mobile Ads XCFramework. Use of the binary SDK and advertising service is also subject to Google's applicable SDK and advertising terms; the Apache-2.0 license for the wrapper must not be read as replacing those service terms.

## Google User Messaging Platform

- Product/module: `GoogleUserMessagingPlatform` / `UserMessagingPlatform`
- Resolved wrapper version: `3.1.0`
- Repository: https://github.com/googleads/swift-package-manager-google-user-messaging-platform
- Resolved revision: `13b248eaa73b7826f0efb1bcf455e251d65ecb1b`
- Dependency path: transitive dependency of the Google Mobile Ads wrapper
- Wrapper license: Apache License 2.0
- Copyright notice: Copyright 2021 Google LLC
- License text: https://github.com/googleads/swift-package-manager-google-user-messaging-platform/blob/3.1.0/LICENSE

The wrapper package downloads Google's precompiled User Messaging Platform XCFramework. Use of the binary SDK and consent service is also subject to Google's applicable terms and privacy requirements.

## Apache License 2.0 Attribution

The two wrapper repositories above are licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0). They are redistributed without modification through Swift Package Manager. Unless required by applicable law or agreed to in writing, software distributed under that license is provided on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

No `NOTICE` file is present at the root of either resolved wrapper repository. No GPL or AGPL dependency appears in the checked-in Swift package resolution.

## Distribution Check

TimeNest exposes a concise version of these notices in Settings > Third-party Licenses, including both wrapper names, the Apache-2.0 license type, Google attribution, and repository links.

Before App Store submission, confirm the exact archive contains only the dependencies above and retain these complete notices with the release records. Also review the then-current Google Mobile Ads SDK terms, AdMob program policies, consent-message configuration, and data-disclosure guidance; those service obligations are not open-source licenses.
