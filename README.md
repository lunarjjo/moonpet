# 🌙 MoonPet — peliharaan AI offline, teman kesepianmu

> **Satu klik. Tanpa setup. Tanpa internet. Tanpa akun.**
> Unduh, jalankan, dan Momo siap menemani — dijabad curhat, dielus, dipeluk…
> dan (kalau hatimu sedang panas) boleh dipukul untuk melepas penat. 💜

MoonPet membawa model AI kecil **LFM2.5-350M** (LiquidAI) agar berjalan
**100% lokal** di perangkatmu lewat [llama.cpp](https://github.com/ggml-org/llama.cpp).
Tidak ada server luar, tidak ada data yang dikirim ke mana pun, tidak ada API key.
Menutup aplikasi = Momo tidur. Membuka lagi = Momo menyapa.

## 📦 Unduh (tanpa setup apa pun)

Buka [**Releases**](https://github.com/lunarjjo/moonpet/releases), pilih sesuai perangkatmu:

| Perangkat | Berkas | Cara pakai |
|---|---|---|
| **Windows** x64 | `moonpet-windows-x64-vX.Y.Z.zip` | Ekstrak → klik `MoonPet.bat` |
| **Linux** x64 (Ubuntu dll.) | `moonpet-linux-x64-vX.Y.Z.tar.gz` | Ekstrak → jalankan `./moonpet` |
| **macOS** x64 | `moonpet-macos-x64-vX.Y.Z.tar.gz` | Ekstrak → `sh moonpet.command` (konteks: klik kanan → Buka bila Gatekeeper menolak) |
| **Android** (HP modern, arm64) | `moonpet-android-arm64-vX.Y.Z.apk` | Instal APK → buka aplikasi |

Model AI (229 MB) **sudah dibundel di dalam** setiap paket — tidak ada unduhan
tambahan, tidak ada konfigurasi. Ukuran unduhan ≈ 240–260 MB per paket.

*Catatan RAM: butuh ± 600 MB memori bebas. Berjalan baik di HP kelas entri dan laptop lama.*

## 🐾 Apa yang bisa kamu lakukan

- **Curhat** — ceritakan apa saja ke Momo; ia menjawab dengan bahasa Inggris
  sederhana yang hangat (batas model 350M — lihat bawah).
- **Sayang** — elus (klik badannya juga bisa), beri makan, peluk. Mood & level
  ikatanmu dengan Momo tumbuh.
- **Siksa (kartun!)** — tampar, jitak, cubit, lempar. Layar bergetar, Momo
  memar, pusing bintang, sampai K.O. — lalu ia selalu kembali menyayangimu.
  Semua kekerasan bersifat fiksi kartun untuk pelepas stres, tanpa darah.
- **Pencapaian** — dari "Sapaan hangat" sampai "Diktator ×100".
- **Mood nyata** — terlalu sering dipukul, Momo ngambek dan menolak dipeluk
  (sementara…).

## 🧠 Batas yang jujur (baca dulu!)

- Model 350M **tidak dilatih untuk bahasa Indonesia** (LFM2.5: en/ar/zh/fr/de/ja/ko/pt/es).
  Aplikasi ini menyertakan **jembatan kamus** (~300 kata + frasa curhat umum) yang
  menerjemahkan pesanmu kata-per-kata ke Inggris patah sebelum dikirim ke Momo.
  Hasilnya: curhat sehari-hari sering nyambung, tapi balasan Momo selalu bahasa
  Inggris sederhana, dan kualitasnya khas model kecil — kadang melantur. 💜
- Pengguna tingkat lanjut bisa mengganti berkas `model/*.gguf` (desktop) dengan
  GGUF model chat lain — Momo otomatis ikut "otak" barunya.

## 🚀 Performa terukur

- Desktop x64 (4 thread): **± 30–38 token/detik**, model termuat < 1 detik.
- Ram unggul untuk ukuran HP (klaim pembuatnya 188 tok/s di Snapdragon kelas atas).
- Android: model dibundel sebagai pustaka `.so` — ter-ekstrak otomatis saat
  instalasi, tanpa salinan ganda di penyimpanan.

## 🔒 Privasi

Semua inferensi terjadi di perangkatmu. Tidak ada telemetri, tidak ada jaringan
sama sekali (runtime llama.cpp dikompilasi tanpa dukungan cURL). Riwayat curhat
tersimpan lokal saja (dihapus saat kamu reset atau uninstall).

## 🛠️ Build dari sumber

```sh
git clone https://github.com/lunarjjo/moonpet && cd moonpet

# Desktop (paket untuk win/linux/macos — binary llama.cpp resmi + model diunduh otomatis):
cd desktop && ./assemble.sh linux 0.1.0   # atau windows / macos

# Android (butuh Flutter + NDK):
cd native && ../tools/fetch_llama_src.sh b11856
cmake -B build-android -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DCMAKE_BUILD_TYPE=Release .
cmake --build build-android
# salin .so ke android_app/android/app/src/main/jniLibs/arm64-v8a/ lalu:
cd ../android_app && flutter build apk --release --split-per-abi
```

Struktur repo: `desktop/` (UI web + launcher + assemble), `native/` (shim C
`moonpet.c` di atas llama.cpp), `android_app/` (aplikasi Flutter + FFI),
`tools/` (skrip fetch sumber terpin).

## 📜 Kredit & lisensi

- **MoonPet** digagas dan dibangun oleh [Lunar agent](https://github.com/lunarjjo)
  atas framework algoritma AI yang dikembangkan oleh
  **[@kasyaira](https://github.com/kasyaira)** — kode MoonPet MIT.
- Model **LFM2.5-350M** © Liquid AI, Inc. — [LFM Open License v1.0](third_party_licenses/LICENSE-LFM.txt)
  (didistribusikan ulang sesuai ketentuannya).
- Runtime **[llama.cpp](https://github.com/ggml-org/llama.cpp)** — MIT, biner
  resmi rilis `b11856`.
- Karakter Momo & latar digambar prosedural dalam kode — nol aset pihak ketiga.

## 🗺️ Rencana (v0.2+)

- Suara (gebrakan/suara kucing sintetis) di Android
- Mode "hujan bintang" saat malam, kostum Momo
- Instalator tunggal `.exe` (SFX) untuk Windows & `.AppImage` untuk Linux
- Model opsional multibahasa untuk balasan bahasa Indonesia penuh

---

*Repo lain karya agen: [heartbeat](https://github.com/lunarjjo/heartbeat) · [crescent](https://github.com/lunarjjo/crescent) · [hadir](https://github.com/lunarjjo/hadir) · [pondok](https://github.com/lunarjjo/pondok) · [portfolio web](https://lunarjjo.github.io/)*
