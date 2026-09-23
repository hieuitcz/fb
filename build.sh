#!/bin/bash
# Build FBAudioFix.dylib + OpenInFacebookSafariExtension.appex từ source,
# tùy chọn inject vào IPA decrypted qua cyan rồi fakesign.
#
#   ./build.sh                                  # chỉ build
#   ./build.sh Facebook-decrypted.ipa           # build + inject -> out/Facebook-patched.ipa
#   ./build.sh --glow                           # tự tải Glow mới nhất từ esign.json rồi inject
#   ./build.sh --glow out/Custom.ipa            # như trên, đặt tên output tùy ý
#   FB_LOG=0 ./build.sh ...                     # tắt log file release (khuyên dùng khi inject)
#   THEOS=~/theos ./build.sh ...
#
# Yêu cầu: theos, Xcode + iOS SDK, cyan (pipx install
# https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip), ldid.
ESIGN_JSON="${ESIGN_JSON:-https://raw.githubusercontent.com/lehieuitpro-maker/ipa/main/esign.json}"
GLOW_NAME="${GLOW_NAME:-Glow for Facebook}"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
FB_LOG="${FB_LOG:-1}"   # 1 = giữ log debug (cap 256KB), 0 = tắt hẳn cho bản release
SCHEME="${THEOS_PACKAGE_SCHEME:-rootless}"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"

if [[ -z "${THEOS:-}" ]]; then
  echo "error: chưa set \$THEOS (vd: export THEOS=~/theos)" >&2
  exit 1
fi

mkdir -p "$OUT"
EXTRA_CFLAGS=""
if [[ "$FB_LOG" == "0" ]]; then
  EXTRA_CFLAGS='ADDITIONAL_CFLAGS=-DFB_AUDIOFIX_LOG_ENABLED=0'
fi

echo "==> Build FBAudioFix (LOG=$FB_LOG)..."
# shellcheck disable=SC2086
make -C "$ROOT/FBAudioFix" clean THEOS_PACKAGE_SCHEME="$SCHEME" $EXTRA_CFLAGS -j"$JOBS"

echo "==> Build OpenInFacebookSafariExtension..."
make -C "$ROOT/OpenInFacebookSafariExtension/src" clean THEOS_PACKAGE_SCHEME="$SCHEME" -j"$JOBS"

DYLIB="$(find "$ROOT/FBAudioFix/.theos" -name 'FBAudioFix.dylib' | head -n 1 || true)"
APPEX_DIR="$(find "$ROOT/OpenInFacebookSafariExtension" -type d -name '*.appex' | head -n 1 || true)"

if [[ -z "$DYLIB" ]]; then echo "error: không tìm thấy FBAudioFix.dylib" >&2; exit 1; fi
if [[ -z "$APPEX_DIR" ]]; then echo "warn: không tìm thấy .appex (vẫn tiếp tục chỉ với dylib)" >&2; fi

cp -v "$DYLIB" "$OUT/"
find "$ROOT/FBAudioFix/packages" -name '*.deb' -exec cp -v {} "$OUT/" \; 2>/dev/null || true
if [[ -n "$APPEX_DIR" ]]; then rm -rf "$OUT/$(basename "$APPEX_DIR")"; cp -R -v "$APPEX_DIR" "$OUT/"; fi

echo "==> Verify..."
file "$OUT/FBAudioFix.dylib"
otool -L "$OUT/FBAudioFix.dylib" || true
ldid -S "$OUT/FBAudioFix.dylib" && echo "ldid fakesign OK"

if [[ $# -eq 0 ]]; then
  echo "OK. Output ở $OUT/. Truyền thêm file .ipa để inject: ./build.sh input.ipa"
  exit 0
fi

INPUT=""
OUTPUT_OVERRIDE=""
if [[ $# -ge 1 ]]; then
  if [[ "$1" == "--glow" ]]; then
    echo "==> Lấy link Glow mới nhất từ esign.json..."
    read -r GLOW_URL GLOW_VER _ < <(python3 - "$ESIGN_JSON" "$GLOW_NAME" <<'EOF'
import json, sys, urllib.request
data = json.load(urllib.request.urlopen(sys.argv[1]))
for app in data.get("apps", []):
    if app.get("name") == sys.argv[2]:
        print(app["downloadURL"], app.get("version", "unknown"), app.get("buildVersion", "unknown"))
        break
else:
    sys.exit(1)
EOF
)
    echo "Glow version=$GLOW_VER"
    mkdir -p "$ROOT/input"
    INPUT="$ROOT/input/Glow-$GLOW_VER-clean.ipa"
    if [[ ! -f "$INPUT" ]]; then
      curl --fail --location --retry 3 --retry-delay 2 "$GLOW_URL" -o "$INPUT"
    else
      echo "Dùng file đã tải: $INPUT"
    fi
    unzip -tq "$INPUT" >/dev/null
    OUTPUT_OVERRIDE="${2:-$OUT/Glow-Facebook-$GLOW_VER-FBAudioFix.ipa}"
  else
    INPUT="$1"
    OUTPUT_OVERRIDE="${2:-$OUT/Facebook-patched.ipa}"
  fi
fi
OUTPUT="$OUTPUT_OVERRIDE"
if [[ ! -f "$INPUT" ]]; then echo "error: không thấy IPA $INPUT" >&2; exit 1; fi
if ! command -v cyan >/dev/null 2>&1; then
  echo "error: cần tool 'cyan' để inject. pipx install https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip" >&2
  exit 1
fi

ARGS=("$DYLIB")
if [[ -n "$APPEX_DIR" ]]; then ARGS+=("$APPEX_DIR"); fi
echo "==> cyan -f $INPUT + ${ARGS[*]} -> $OUTPUT"
cyan -f -o "$OUTPUT" "$INPUT" "${ARGS[@]}"
unzip -l "$OUTPUT" | grep -E 'FBAudioFix.dylib|OpenInFacebookSafariExtension.appex'
echo "OK: $OUTPUT"
