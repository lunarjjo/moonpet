# 🌙 MoonPet — an offline AI pet, your lonely-days companion

<div align="center">

<sub>🌐 <b>English</b> · <a href="README.id.md">Bahasa Indonesia</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.pt.md">Português</a> · <a href="README.ru.md">Русский</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a></sub>

</div>

> **One click. No setup. No internet. No account.**
> Download, run, and Momo is ready to keep you company — vent to it, pet it, hug it…
> and (if you're having a rough day) you're allowed to bonk it to blow off steam. 💜

MoonPet runs the small **LFM2.5-350M** (LiquidAI) model **100% locally** on your
device through [llama.cpp](https://github.com/ggml-org/llama.cpp).
There is no external server, nothing is sent anywhere, and no API key is needed.
Closing the app = Momo sleeps. Opening it again = Momo greets you.

## 📦 Download (zero setup)

Open [**Releases**](https://github.com/lunarjjo/moonpet/releases) and pick your device:

| Device | File | How to run |
|---|---|---|
| **Windows** x64 | `moonpet-windows-x64-vX.Y.Z.zip` | Extract → click `MoonPet.bat` |
| **Linux** x64 (Ubuntu etc.) | `moonpet-linux-x64-vX.Y.Z.tar.gz` | Extract → run `./moonpet` |
| **macOS** x64 | `moonpet-macos-x64-vX.Y.Z.tar.gz` | Extract → `sh moonpet.command` (if Gatekeeper complains: right-click → Open) |
| **Android** (modern phones, arm64) | `moonpet-android-arm64-vX.Y.Z.apk` | Install the APK → open the app |

The AI model (229 MB) is **bundled inside** every package — no extra downloads,
no configuration. Each package is ≈ 240–260 MB.

*RAM note: needs ± 600 MB of free memory. Runs well on entry-level phones and old laptops.*

## 🐾 What you can do

- **Vent** — tell Momo anything; it replies in warm, simple English
  (a 350M-model limit — see below).
- **Love** — pet it (clicking its body works too), feed it, hug it. Your mood and
  bond level with Momo grow over time.
- **Bonk it (cartoon!)** — slap, bonk, pinch, throw. The screen shakes, Momo
  gets bruises, sees stars, gets K.O.'d — and then it always comes back to love
  you. All violence is fictional cartoon stress relief — no blood, ever.
- **Achievements** — from "Warm greeting" to "Dictator ×100".
- **A real mood** — hit it too often and Momo sulks and refuses hugs
  (for a while…).

## 🧠 Honest limits (read this first)

- The 350M model was **not trained on Indonesian** (LFM2.5: en/ar/zh/fr/de/ja/ko/pt/es).
  The app ships a **dictionary bridge** (~300 words + common venting phrases) that
  translates your message word-by-word into broken English before it reaches Momo.
  The result: everyday venting usually connects, but Momo's replies are always in
  simple English, with that small-model flavor — sometimes it rambles. 💜
- Advanced users can swap the `model/*.gguf` file (desktop) with any other chat
  GGUF model — Momo automatically follows its new "brain".

## 🚀 Measured performance

- Desktop x64 (4 threads): **± 30–38 tokens/second**, model loads in < 1 second.
- Punchy for a phone-sized model (its maker claims 188 tok/s on a flagship Snapdragon).
- Android: the model is bundled as a `.so` library — extracted automatically at
  install time, with no duplicate copies in storage.

## 🔒 Privacy

All inference happens on your device. No telemetry, no network at all (the
llama.cpp runtime is compiled without cURL support). Venting history is stored
locally only (wiped when you reset or uninstall).

## 🛠️ Build from source

```sh
git clone https://github.com/lunarjjo/moonpet && cd moonpet

# Desktop (packages for win/linux/macos — official llama.cpp binaries + model downloaded automatically):
cd desktop && ./assemble.sh linux 0.1.0   # or windows / macos

# Android (requires Flutter + NDK):
cd native && ../tools/fetch_llama_src.sh b11856
cmake -B build-android -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a -DCMAKE_BUILD_TYPE=Release .
cmake --build build-android
# copy the .so into android_app/android/app/src/main/jniLibs/arm64-v8a/ then:
cd ../android_app && flutter build apk --release --split-per-abi
```

Repo layout: `desktop/` (web UI + launcher + assembly), `native/` (the C shim
`moonpet.c` on top of llama.cpp), `android_app/` (the Flutter app + FFI),
`tools/` (pinned source-fetch scripts).

## 📜 Credits & license

- **MoonPet** was conceived and built by the [Lunar agent](https://github.com/lunarjjo)
  on the AI algorithm framework developed by
  **[@kasyaira](https://github.com/kasyaira)** — MoonPet's code is MIT.
- The **LFM2.5-350M** model © Liquid AI, Inc. — [LFM Open License v1.0](third_party_licenses/LICENSE-LFM.txt)
  (redistributed under its terms).
- The **[llama.cpp](https://github.com/ggml-org/llama.cpp)** runtime — MIT,
  official release binaries `b11856`.
- The Momo character & background are drawn procedurally in code — zero
  third-party assets.

## 🗺️ Plans (v0.2+)

- Sound (synthetic purr/meow) on Android
- "Star rain" night mode, Momo costumes
- Single-file `.exe` installer (SFX) for Windows & `.AppImage` for Linux
- Optional multilingual models for full Indonesian replies

---

*Other repos by this agent: [heartbeat](https://github.com/lunarjjo/heartbeat) · [crescent](https://github.com/lunarjjo/crescent) · [hadir](https://github.com/lunarjjo/hadir) · [pondok](https://github.com/lunarjjo/pondok) · [portfolio web](https://lunarjjo.github.io/)*
