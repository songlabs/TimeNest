# PP-OCR iOS Calendar Recognition and Recognition-Only A/B POC

PP-OCRv6 is the primary per-cell OCR engine for monthly Calendar Photo Import. Its locally recognized text and visual-order bounding boxes feed the existing `CalendarImportCandidateBuilder`. Cell-level Apple Vision fallback remains limited to PP-OCR technical failures. A separate detection-level Vision pass may run only after a suspicious, unparsed PP-OCR detection also fails semantic recovery through enhanced PP-OCRv6 and the PP-OCRv5 candidate.

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
| A/B candidate recognition | `ch_PP-OCRv5_rec_mobile.onnx` | 16,631,306 | `5825fc7ebf84ae7a412be049820b4d86d77620f204a041697b0494669b1742c5` | `https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv5/rec/ch_PP-OCRv5_rec_mobile.onnx` |
| A/B candidate characters | `ppocrv5_dict.txt` | 74,012 | `d1979e9f794c464c0d2e0b70a7fe14dd978e9dc644c0e71f14158cdf8342af1b` | `https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/paddle/PP-OCRv5/rec/ch_PP-OCRv5_rec_mobile/ppocrv5_dict.txt` |

The candidate weights originate from PaddleOCR's official `PP-OCRv5_mobile_rec_infer.tar` (`566b9512b34e34a9f0db54d87b51fa5a0b9ed2cf1ab7e49728cc0b8b5a64f414`) at `https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0//PP-OCRv5_mobile_rec_infer.tar`. The checked-in dictionary has 18,383 entries and was verified entry-for-entry against both that official package's `PostProcess.character_dict` and the converted ONNX `character` metadata. The ONNX is RapidOCR's conversion of those PaddleOCR weights; its published checksum was independently verified.

The largest file is below GitHub's 100 MB per-file limit. Git LFS is not used. The four ONNX files total 48,380,815 bytes (about 46.14 MiB) before App Store compression or archive thinning. The candidate ONNX and dictionary add 16,705,318 bytes (about 15.93 MiB) to the uncompressed resources.

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

The primary recognition pass uses no CLAHE, binarization, sharpening, custom grayscale conversion, OCR output repair, or global punctuation replacement. A triggered detection-level recovery uses one bounded variant: a 6% detection-crop margin, grayscale, fixed contrast enhancement, and up to 3x source upscale for crops below 96 pixels high. Detector thresholds, detector unclip, Grid geometry, perspective correction, and Cell bounds are unchanged.

## Candidate recognizer and detection-level time recovery

The primary candidate input remains `PP-OCRv6_rec_small`. The secondary candidate is PaddleOCR's official `PP-OCRv5_mobile_rec`, represented by RapidOCR's `ch_PP-OCRv5_rec_mobile.onnx` conversion. PaddleOCR documents this model family as supporting Simplified Chinese, Traditional Chinese, English, and Japanese in one model and as targeting difficult scenarios including handwriting. The mobile model was selected instead of the roughly 81 MB server model to bound iOS bundle and runtime cost; this selection does not assert that it is more accurate on the TimeNest photo.

For every rectified Cell, TimeNest runs the existing detector once and the existing 0/180 classifier once. After classification, both recognition models receive the same primary tensor. If PP-OCRv6 is unparsed and either below `0.65` confidence or sufficiently time-like, TimeNest also runs the bounded enhanced PP-OCRv6 variant. Pure numeric tokens outside the bounded 7–9 digit compact format do not trigger on low confidence alone, which preserves rejection of date fragments and short numeric noise such as `4`, `40`, and `20002`. A valid current result always wins. Otherwise, the first complete, forward-moving time range is selected in this order: enhanced PP-OCRv6, PP-OCRv5 candidate, detection-level Vision. Confidence alone never replaces the current result. If no secondary result is a valid range, the original text remains and the Candidate Builder continues to reject it as `noParsedTime`.

Month parsing additionally accepts only unlabelled, all-digit sources of length 7 through 9. Seven digits must have one unique `HMMHHMM` or `HHMMHMM` interpretation; eight digits must be `HHMMHHMM`; nine digits may drop at most one leading or trailing digit and must leave one unique eight-digit interpretation. Hours, minutes, and forward range order are validated. Compact and secondary recoveries are marked `recovered` and always require review. Day scan parsing is unchanged.

Both recognition sessions initialize at most once for a `PPOCRService` instance. A candidate resource, initialization, shape, or inference failure is reported in `[RecognitionModelPOC]` and does not fail the current model's Cell. Per-detection diagnostics preserve the original v6 text and confidence and separately record the trigger, enhanced/candidate/Vision results, semantic parse results, selected text/source, selection reason, and timings. Images and crops are never included.

Compatibility was checked with ONNX Runtime 1.29.0. Both models have one float input shaped `[N, 3, 48, dynamicWidth]` and one CTC output shaped `[N, timeSteps, classes]`. The candidate uses ONNX opset 14 and outputs 18,385 classes, exactly matching blank + 18,383 dictionary entries + appended space. Physical iOS initialization, memory, latency, and Japanese handwriting quality still require Xcode/TestFlight validation.

## Ported behavior and known compatibility boundary

The implementation follows RapidOCR's detection resize/normalization/NCHW layout, thresholding, 2x2 dilation, contour components, minimum-area boxes, fast box score, rectangular unclip distance, clipping, and stable visual line sorting. It also follows perspective crop, 0/180 classification, recognition resize/padding, argmax CTC decoding, adjacent duplicate removal, blank removal, and selected-token mean confidence.

The iOS rewrite uses Core Graphics to obtain cell pixels and a Swift implementation of contour/minimum-area geometry rather than Python OpenCV, pyclipper, and Shapely. Perspective sampling is rewritten in Swift. Therefore exact floating-point boxes, interpolation, and final strings can differ from RapidOCR Python even with the same ONNX weights and parameters; physical-device validation must measure that difference rather than assume equivalence.

## Runtime scope and privacy

Every grid-derived `CalendarImportDayRegion` is processed in day order with one shared model/session set per `PPOCRService`. PP-OCR does not infer the year, month, day, grid, or day mapping.

Both Apple Vision and PP-OCR run locally. No image, crop, or OCR text is uploaded. The path has no backend, API key, cloud OCR call, or network dependency, so it is designed to run in airplane mode; actual airplane-mode behavior remains a physical-device/TestFlight acceptance check.
