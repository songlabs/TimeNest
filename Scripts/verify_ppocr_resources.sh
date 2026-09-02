#!/bin/bash

set -euo pipefail

resource_dir="TimeNest/Resources/PPOCR"

verify_file() {
  local file_name="$1"
  local expected_bytes="$2"
  local expected_sha256="$3"
  local file_path="$resource_dir/$file_name"

  test -f "$file_path"
  actual_bytes=$(wc -c < "$file_path" | tr -d '[:space:]')
  test "$actual_bytes" = "$expected_bytes"
  if command -v shasum >/dev/null 2>&1; then
    actual_sha256=$(shasum -a 256 "$file_path" | awk '{print $1}')
  else
    actual_sha256=$(sha256sum "$file_path" | awk '{print $1}')
  fi
  test "$actual_sha256" = "$expected_sha256"
}

verify_file \
  "PP-OCRv6_det_small.onnx" \
  "9929594" \
  "090f04abcd9d9a7498bc4ebf677e4cb9bdce1fe4197ddb7e529f1ef44e1ff94f"
verify_file \
  "ch_ppocr_mobile_v2.0_cls_mobile.onnx" \
  "585532" \
  "e47acedf663230f8863ff1ab0e64dd2d82b838fceb5957146dab185a89d6215c"
verify_file \
  "PP-OCRv6_rec_small.onnx" \
  "21234383" \
  "6f327246b50388f3c176ae304bd95767ea6dc0c9ae92153ef8cbe210b3c14884"
verify_file \
  "PP-OCRv6_rec_small.characters.txt" \
  "74947" \
  "b5f2bfe2bdd9448429e3e82b51c789775d9b42f2403d082b00662eb77e401c5d"
verify_file \
  "ch_PP-OCRv5_rec_mobile.onnx" \
  "16631306" \
  "5825fc7ebf84ae7a412be049820b4d86d77620f204a041697b0494669b1742c5"
verify_file \
  "ppocrv5_dict.txt" \
  "74012" \
  "d1979e9f794c464c0d2e0b70a7fe14dd978e9dc644c0e71f14158cdf8342af1b"

test "$(wc -l < "$resource_dir/PP-OCRv6_rec_small.characters.txt" | tr -d '[:space:]')" = "18708"
test "$(wc -l < "$resource_dir/ppocrv5_dict.txt" | tr -d '[:space:]')" = "18383"

echo "PP-OCR resources verified."
