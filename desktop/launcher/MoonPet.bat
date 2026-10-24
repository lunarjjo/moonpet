@echo off
rem ============================================================
rem  MoonPet — peluncur satu-klik (Windows)
rem  Menjalankan otak lokal (llama-server + model LFM2.5-350M)
rem  lalu membuka jendela MoonPet di browser bawaan.
rem  Ditutup = otak ikut mati (tidak ada proses menggantung).
rem ============================================================
title MoonPet - otak lokal Momo
cd /d "%~dp0"
set PORT=8199
set MODEL=model\moonpet-lfm2.5-350m-q4km.gguf

if not exist "%MODEL%" (
  echo [!] Berkas model tidak ditemukan: %MODEL%
  echo     Unduh ulang paket MoonPet yang utuh.
  pause
  exit /b 1
)

echo  ##    ##  ######   ##     ## ########
echo  ##   ##  ##    ##  ##     ## ##     ##
echo  ##  ##   ##        ##     ## ##     ##
echo  #####    ##        ######### ########
echo  ##  ##   ##        ##     ## ##     ##
echo  ##   ##  ##    ##  ##     ## ##     ##
echo  ##    ##  ######   ##     ## ##     ##
echo.
echo  Momo menyiapkan otaknya... (beberapa detik)
echo  Jendela ini adalah SERVER Momo - biarkan terbuka.
echo  Tutup jendela ini saat selesai bermain.
echo.

rem beri server 4 detik untuk siap sebelum membuka browser
start "" cmd /c "timeout /t 4 /nobreak >nul & start http://127.0.0.1:%PORT%/"

"llama-server.exe" -m "%MODEL%" --host 127.0.0.1 --port %PORT% -c 2048 --path ui

echo.
echo  Momo tidur. Sampai jumpa!
timeout /t 3 /nobreak >nul
