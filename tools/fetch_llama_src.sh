#!/bin/sh
# fetch sumber llama.cpp versi terpin untuk build native MoonPet
set -eu
TAG="${1:-b11856}"
SHA="${2:-}"
DIR="$(cd "$(dirname "$0")/.." && pwd)/native/llama"
rm -rf "$DIR"
mkdir -p "$DIR"
T="$(mktemp -d)"
curl -fL --retry 3 -o "$T/src.tar.gz" "https://github.com/ggml-org/llama.cpp/archive/refs/tags/${TAG}.tar.gz"
tar xzf "$T/src.tar.gz" -C "$T"
mv "$T"/llama.cpp-*/* "$DIR"/
rm -rf "$T"
echo "llama.cpp ${TAG} -> $DIR"
