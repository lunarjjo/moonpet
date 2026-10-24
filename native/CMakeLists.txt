# MoonPet native — shim C + llama.cpp (submodule-style fetch oleh CI)
# Host build : cmake -B build-host . && cmake --build build-host
# Android    : cmake -B build-android . -DCMAKE_TOOLCHAIN_FILE=$NDK/... -DANDROID_ABI=arm64-v8a
cmake_minimum_required(VERSION 3.22)
project(moonpet-native LANGUAGES C CXX)

set(LLAMA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/llama" CACHE PATH "sumber llama.cpp")

if(NOT EXISTS "${LLAMA_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "sumber llama.cpp tidak ditemukan di ${LLAMA_DIR} — fetch terlebih dahulu (lihat tools/fetch_llama_src.sh)")
endif()

# konfigurasi llama.cpp: library saja, tanpa jaringan & tanpa OpenMP (NDK)
set(LLAMA_BUILD_TESTS    OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER   OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL           OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON   ON  CACHE BOOL "" FORCE)
if(ANDROID)
    # NDK: OpenMP opsional & bermasalah — threadpool internal ggml memadai di kernel asli
    set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
endif()
set(GGML_BACKEND_DL     OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS    ON  CACHE BOOL "" FORCE)

# SIMD untuk build host/desktop x86_64. PENTING (teruji di sandbox):
# - GGML_NATIVE default ON menghasilkan -march=native; jika CPU mengiklankan
#   AVX-512 tapi VM mengeksekusinya via trap (emulasi), performa runtuh ~77x.
# - Karena itu: NATIVE OFF + flag eksplisit AVX2/FMA/F16C (profil "haswell")
#   = cepat di semua CPU modern tanpa risiko jalur AVX-512.
# Android (arm64) tidak berjalan ke cabang ini.
if(NOT ANDROID AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64)$")
    message(STATUS "moonpet: SIMD eksplisit AVX2+FMA+F16C (non-native, hindari AVX-512)")
    set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
    set(GGML_SSE42 ON CACHE BOOL "" FORCE)
    set(GGML_AVX   ON CACHE BOOL "" FORCE)
    set(GGML_FMA   ON CACHE BOOL "" FORCE)
    set(GGML_F16C  ON CACHE BOOL "" FORCE)
    set(GGML_BMI2  ON CACHE BOOL "" FORCE)
    set(GGML_AVX2  ON CACHE BOOL "" FORCE)
    set(GGML_AVX512 OFF CACHE BOOL "" FORCE)
endif()

add_subdirectory("${LLAMA_DIR}" llama_build EXCLUDE_FROM_ALL)

add_library(moonpet SHARED moonpet.c)
target_link_libraries(moonpet PRIVATE llama)
target_include_directories(moonpet PRIVATE "${LLAMA_DIR}/include")
# Android: logcat untuk log bawaan; platform lain diam
if(ANDROID)
    target_link_libraries(moonpet PRIVATE log)
endif()
