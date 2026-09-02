# PP-OCRv6 iOS Calendar Recognition

PP-OCRv6 is the primary per-cell OCR engine for monthly Calendar Photo Import. Its locally recognized text and visual-order bounding boxes feed the existing `CalendarImportCandidateBuilder`. Apple Vision runs only for cells where PP-OCR cannot initialize or returns a technical inference error.

## Runtime integration

- Runtime: Microsoft official `onnxruntime-objc` CocoaPod
- Exact version: `1.29.0`
- CocoaPods version in CI/TestFlight: `1.16.2`
- Pod source archive: `https://download.onnxruntime.ai/pod-archive-onnxruntime-objc-1.29.0.zip`
- Integration order: Tuist generation, `pod install`, workspace package resolution, build/test/archive
- Swift access: the official Objective-C API through `TimeNest-Bridging-Header.h`
- Execution provider: default CPU provider; the implementation does not enable CoreML or convert the models

The Podfile disables `CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER` only for the official `onnxruntime-objc` target because of the Xcode 26.3 header/runtime issue documented as `microsoft/onnxruntime#27717`.

## Exact model files

All files come from the RapidAI/RapidOCR official ModelScope model repository, revision `v3.9.2`.

| Stage | File | Bytes | SHA256 | Source |
|---|---|---:|---|---|
| Detection | `PP-OCRv6_det_small.onnx` | 9,929,594 | `090f04abcd9d9a7498bc4ebf677e4cb9bdce1fe4197ddb7e529f1ef44e1ff94f` | `https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/det/PP-OCRv6_det_small.onnx` |
| Classification | `ch_ppocr_mobile_v2.0_cls_mobile.onnx` | 585,532 | `e47acedf663230f8863ff1ab0e64dd2d82b838fceb5957146dab185a89d6215c` | `https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv4/cls/ch_ppocr_mobile_v2.0_cls_mobile.onnx` |
| Recognition | `PP-OCRv6_rec_small.onnx` | 21,234,383 | `6f327246b50388f3c176ae304bd95767ea6dc0c9ae92153ef8cbe210b3c14884` | `https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/rec/PP-OCRv6_rec_small.onnx` |
| Recognition characters | `PP-OCRv6_rec_small.characters.txt` | 74,947 | `b5f2bfe2bdd9448429e3e82b51c789775d9b42f2403d082b00662eb77e401c5d` | mechanically extracted from the `character` metadata of the exact recognition ONNX file |

The largest file is below GitHub's 100 MB per-file limit. Git LFS is not used. The three ONNX files total 31,749,509 bytes (about 30.28 MiB) before App Store compression or archive thinning.

## Recognition parameters

- `Global.text_score = 0.30`
- Detection model: PP-OCRv6 small
- `limit_side_len = 960`
- `limit_type = min`
- Detection normalization: scale `1/255`, mean `[0.5, 0.5, 0.5]`, standard deviation `[0.5, 0.5, 0.5]`
- `thresh = 0.20`
- `box_thresh = 0.35`
- `unclip_ratio = 1.8`
- `use_dilation = true`
- `score_mode = fast`
- Classification model: `ch_ppocr_mobile_v2.0_cls_mobile`, input `[3, 48, 192]`, labels `0/180`, threshold `0.9`
- Recognition model: PP-OCRv6 small
- `rec_img_shape = [3, 48, 320]`, with RapidOCR-compatible dynamic width expansion

No CLAHE, binarization, sharpening, custom grayscale conversion, OCR output repair, punctuation repair, time normalization, or multi-version A/B path is applied.

## Ported behavior and known compatibility boundary

The implementation follows RapidOCR's detection resize/normalization/NCHW layout, thresholding, 2x2 dilation, contour components, minimum-area boxes, fast box score, rectangular unclip distance, clipping, and stable visual line sorting. It also follows perspective crop, 0/180 classification, recognition resize/padding, argmax CTC decoding, adjacent duplicate removal, blank removal, and selected-token mean confidence.

The iOS rewrite uses Core Graphics to obtain cell pixels and a Swift implementation of contour/minimum-area geometry rather than Python OpenCV, pyclipper, and Shapely. Perspective sampling is rewritten in Swift. Therefore exact floating-point boxes, interpolation, and final strings can differ from RapidOCR Python even with the same ONNX weights and parameters; physical-device validation must measure that difference rather than assume equivalence.

## Runtime scope and privacy

Every grid-derived `CalendarImportDayRegion` is processed in day order with one shared model/session set per `PPOCRService`. PP-OCR does not infer the year, month, day, grid, or day mapping.

Both Apple Vision and PP-OCR run locally. No image, crop, or OCR text is uploaded. The path has no backend, API key, cloud OCR call, or network dependency, so it is designed to run in airplane mode; actual airplane-mode behavior remains a physical-device/TestFlight acceptance check.
