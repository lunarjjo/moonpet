#!/bin/sh
# ============================================================
# MoonPet — assemble paket desktop (dipakai CI & lokal)
# Pemakaian: ./assemble.sh <linux|windows|macos> <versi>
# Env opsional (hindari unduh ulang saat uji lokal):
#   LLAMA_ARCHIVE=/path/ke/arsip-llama.tar.gz|zip
#   MODEL_FILE=/path/ke/model.gguf
# ============================================================
set -eu

TARGET="${1:?pemakaian: assemble.sh <linux|windows|macos> <versi>}"
VERSION="${2:-0.1.0}"

LLAMA_TAG="b11856"
# SHA256 arsip binary llama.cpp resmi (ggml-org/llama.cpp releases)
case "$TARGET" in
  linux)   LLAMA_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_TAG}/llama-${LLAMA_TAG}-bin-ubuntu-x64.tar.gz"
           LLAMA_SHA="71b660dd4a90c13db899acdef59862226f7ec8d27907b7c107febc99904c00be" ;;
  windows) LLAMA_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_TAG}/llama-${LLAMA_TAG}-bin-win-cpu-x64.zip"
           LLAMA_SHA="b0be608ec81c811029406430796dfcd16b8d83dc152705a6682f0d47834a2f3b" ;;
  macos)   LLAMA_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_TAG}/llama-${LLAMA_TAG}-bin-macos-x64.tar.gz"
           LLAMA_SHA="a06974186c508a8cb229803b5561fc6f0540702197fdd2dafc243fcee1d44708" ;;
  *) echo "target tidak dikenal: $TARGET" >&2; exit 1 ;;
esac

MODEL_URL="https://huggingface.co/LiquidAI/LFM2.5-350M-GGUF/resolve/main/LFM2.5-350M-Q4_K_M.gguf"
MODEL_SHA="7e6f72643caafc9a68256686638c4d7916f2cec76d1df478d4c3ddcd95a6aed4"
MODEL_NAME="moonpet-lfm2.5-350m-q4km.gguf"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
OUTDIR="${ROOT}/dist"
OUTROOT="moonpet-${TARGET}-x64-v${VERSION}"
PKG="${OUTDIR}/${OUTROOT}"
mkdir -p "$PKG" "$OUTDIR"

fetch() { # fetch <url> <sha> <out>
  [ -f "$3" ] || curl -fL --retry 3 -o "$3" "$1"
  printf '%s  %s\n' "$2" "$3" | sha256sum -c - >/dev/null || {
    echo "[!] SHA256 tidak cocok untuk $3" >&2; rm -f "$3"; exit 1; }
}

echo "== [1/4] unduh runtime llama.cpp (${LLAMA_TAG}) =="
LLAMA_ARCHIVE="${LLAMA_ARCHIVE:-${WORK}/llama-bin}"
fetch "$LLAMA_URL" "$LLAMA_SHA" "$LLAMA_ARCHIVE"

echo "== [2/4] unduh model LFM2.5-350M Q4_K_M (229 MB) =="
MODEL_FILE="${MODEL_FILE:-${WORK}/model.gguf}"
fetch "$MODEL_URL" "$MODEL_SHA" "$MODEL_FILE"

echo "== [3/4] susun paket =="
mkdir -p "${PKG}/model" "${PKG}/ui"
cp -r "${ROOT}/desktop/ui/." "${PKG}/ui/"
cp "$MODEL_FILE" "${PKG}/model/${MODEL_NAME}"

if [ "$TARGET" = "windows" ]; then
  unzip -q -o "$LLAMA_ARCHIVE" -d "$WORK/llama"
  find "$WORK/llama" -name 'llama-server.exe' -exec cp {} "$PKG/" \;
  find "$WORK/llama" -name '*.dll' -exec cp {} "$PKG/" \;
  cp "${ROOT}/desktop/launcher/MoonPet.bat" "$PKG/"
  # .bat wajib CRLF supaya andal di cmd.exe
  sed -i 's/$/\r/' "$PKG/MoonPet.bat" || perl -pi -e 's/\n/\r\n/' "$PKG/MoonPet.bat"
else
  mkdir -p "$WORK/llama_x"
  tar xzf "$LLAMA_ARCHIVE" -C "$WORK/llama_x"
  LLAMA_BIN="$(find "$WORK/llama_x" -name llama-server -type f | head -1)"
  cp "$LLAMA_BIN" "$PKG/"
  # hanya pustaka yang dipakai llama-server: ggml (semua varian CPU dispatch),
  # libllama, common, mtmd, dan impl server. Buang impl tool lain (cli/bench/dll).
  find "$(dirname "$LLAMA_BIN")" \( -name 'libggml*.so*' -o -name 'libllama.so*' \
    -o -name 'libllama-common.so*' -o -name 'libmtmd.so*' \
    -o -name 'libllama-server-impl.so' \) -exec cp {} "$PKG/" \;
  find "$(dirname "$LLAMA_BIN")" -name '*.dylib' -exec cp {} "$PKG/" \; 2>/dev/null || true
  cp "${ROOT}/desktop/launcher/moonpet.sh" "$PKG/moonpet"
  chmod +x "$PKG/moonpet"
  if [ "$TARGET" = "macos" ]; then
    # .command: klik-ganda di Finder membuka Terminal & menjalankan launcher
    cp "${ROOT}/desktop/launcher/moonpet.sh" "$PKG/moonpet.command"
    chmod +x "$PKG/moonpet.command"
  fi
fi

# lisensi & atribusi (wajib LFM Open License v1.0 + MIT llama.cpp)
cp "${ROOT}/LICENSE" "${PKG}/LICENSE-MoonPet" 2>/dev/null || true
cp "${ROOT}/LICENSES-NOTICE.md" "${PKG}/"
cp "${ROOT}/third_party_licenses/LICENSE-LFM.txt" "${PKG}/LICENSE-LFM.txt" 2>/dev/null || true
printf 'MoonPet v%s\nCara pakai:\n  Windows : ekstrak lalu klik MoonPet.bat\n  Linux   : ekstrak lalu jalankan ./moonpet\n  macOS   : ekstrak lalu klik-ganda moonpet.command\n  Android : pasang APK\n\nSitus Momo dibuka di browser bawaan; jendela terminal yang muncul\nadalah SERVER Momo — biarkan terbuka selama bermain.\n' "$VERSION" > "${PKG}/BACA-DULU.txt"

echo "== [4/4] kompres =="
cd "$OUTDIR"
if [ "$TARGET" = "windows" ]; then
  ( cd "$OUTDIR" && zip -q -r "${OUTROOT}.zip" "$OUTROOT" )
  echo "SELESAI: ${OUTDIR}/${OUTROOT}.zip"
else
  ( cd "$OUTDIR" && tar czf "${OUTROOT}.tar.gz" "$OUTROOT" )
  echo "SELESAI: ${OUTDIR}/${OUTROOT}.tar.gz"
fi
rm -rf "$WORK" "$PKG"
