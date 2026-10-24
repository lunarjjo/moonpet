#!/bin/sh
# ============================================================
#  MoonPet — peluncur satu-klik (Linux)
#  Menjalankan otak lokal (llama-server + model LFM2.5-350M)
#  lalu membuka MoonPet di browser bawaan.
# ============================================================
cd "$(dirname "$0")" || exit 1
PORT=8199
MODEL="model/moonpet-lfm2.5-350m-q4km.gguf"

if [ ! -f "$MODEL" ]; then
  echo "[!] Berkas model tidak ditemukan: $MODEL"
  echo "    Unduh ulang paket MoonPet yang utuh."
  exit 1
fi

echo ' ##    ##  ######   ##     ## ########'
echo ' ##   ##  ##    ##  ##     ## ##     ##'
echo ' ##  ##   ##        ##     ## ##     ##'
echo ' #####    ##        ######### ########'
echo ' ##  ##   ##        ##     ## ##     ##'
echo ' ##   ##  ##    ##  ##     ## ##     ##'
echo ' ##    ##  ######   ##     ## ##     ##'
echo
echo ' Momo menyiapkan otaknya... (beberapa detik)'
echo ' Jendela ini adalah SERVER Momo - biarkan terbuka.'
echo ' Tekan Ctrl+C saat selesai bermain.'
echo

# buka browser setelah server siap (4 detik)
( sleep 4
  ( xdg-open "http://127.0.0.1:${PORT}/" >/dev/null 2>&1 ) ||
  ( gio open "http://127.0.0.1:${PORT}/" >/dev/null 2>&1 ) ||
  ( x-www-browser "http://127.0.0.1:${PORT}/" >/dev/null 2>&1 ) ||
  echo "Buka manual: http://127.0.0.1:${PORT}/"
) &

exec ./llama-server -m "$MODEL" --host 127.0.0.1 --port "$PORT" -c 2048 --path ui
