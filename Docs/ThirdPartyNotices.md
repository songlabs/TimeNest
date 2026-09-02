# TimeNest Third-Party Notices

This inventory covers the checked-in Swift package resolutions and PP-OCR iOS dependencies as of 2026-09-03. Recheck this document whenever package, CocoaPod, or bundled-model versions change.

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

## Microsoft ONNX Runtime

- Product/module: `onnxruntime-objc`
- Exact CocoaPod version: `1.29.0`
- Distribution: Microsoft official CocoaPod archive resolved by CocoaPods 1.16.2
- Repository: https://github.com/microsoft/onnxruntime
- License: MIT
- Copyright notice: Copyright (c) Microsoft Corporation
- License text: https://github.com/microsoft/onnxruntime/blob/v1.29.0/LICENSE

PP-OCR uses ONNX Runtime locally on iOS. No ONNX Runtime Swift wrapper or third-party binary mirror is used.

## RapidOCR

- Component: preprocessing, DB postprocessing, box sorting, classifier handling, dynamic recognition resize, and CTC decoding behavior ported to Swift
- Model repository revision: `v3.9.2`
- Reference implementation commit: `0e629c8be05635035c01a829d10a91bbcd56a27a`
- Repository: https://github.com/RapidAI/RapidOCR
- License: Apache License 2.0
- Copyright notice: Copyright (c) 2021 RapidOCR Authors
- License text: https://github.com/RapidAI/RapidOCR/blob/0e629c8be05635035c01a829d10a91bbcd56a27a/LICENSE

The Swift implementation is a modified rewrite for TimeNest iOS. It does not include the RapidOCR Python runtime, OpenCV, pyclipper, Shapely, or any network service.

## PaddleOCR / PP-OCR Models

- Models: `PP-OCRv6_det_small.onnx`, `ch_ppocr_mobile_v2.0_cls_mobile.onnx`, `PP-OCRv6_rec_small.onnx`, and diagnostic-only `ch_PP-OCRv5_rec_mobile.onnx`
- Source: https://www.modelscope.cn/models/RapidAI/RapidOCR (revision `v3.9.2`)
- Upstream project: https://github.com/PaddlePaddle/PaddleOCR
- License: Apache License 2.0
- Model copyright: Baidu
- License text: https://github.com/PaddlePaddle/PaddleOCR/blob/main/LICENSE

The four ONNX files and their matching recognition dictionaries are bundled for local PP-OCR recognition. Their source URLs, byte sizes, SHA256 values, and the PP-OCRv5 official-weight provenance are recorded in `Docs/PPOCRv6IOSPOC.md` and verified in CI. The PP-OCRv5 model is used only for recognition A/B diagnostics; PP-OCRv6 remains the Calendar Candidate input.

## Apache License 2.0 Attribution

The Google wrappers, RapidOCR reference implementation, and PaddleOCR/PP-OCR model distribution above use the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0). Unless required by applicable law or agreed to in writing, software distributed under that license is provided on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

No GPL or AGPL dependency is introduced by this implementation.

## Distribution Check

TimeNest exposes concise notices in Settings > Third-party Licenses for the two Google wrappers, ONNX Runtime, RapidOCR, and the PP-OCR models, including license types, attribution, and source links.

Before App Store submission, confirm the exact archive dependency/model inventory and retain these complete notices with the release records. Also review the then-current Google Mobile Ads SDK terms, AdMob program policies, consent-message configuration, and data-disclosure guidance; those service obligations are not open-source licenses.
