#!/bin/bash
# Builds libaom into aom-apple/ for the vox_av1 pod: libaom.xcframework (macOS,
# iOS and the iOS simulator) and its headers. x86_64 is plain C; arm64 keeps
# libaom's NEON code.
set -euo pipefail
out="$(cd "$(dirname "$0")" && pwd)/aom-apple"
tmp=$(mktemp -d)
curl -sSL -o "$tmp/aom.tgz" https://raw.githubusercontent.com/jade-on-mesh/meshcore-open-tak/deps-cache/aom-v3.12.1.tar.gz
echo "76558ad5918820d66fa78460d9957e5bbf7cf9eef1a5421b5ba5e616f200d76e  $tmp/aom.tgz" | shasum -a 256 -c
tar xzf "$tmp/aom.tgz" -C "$tmp"

build() { # build directory, then extra CMake arguments
  cmake -S "$tmp/aom" -B "$tmp/$1" "${@:2}" -DCMAKE_BUILD_TYPE=Release -DENABLE_DOCS=0 -DENABLE_EXAMPLES=0 \
    -DENABLE_TESTS=0 -DENABLE_TESTDATA=0 -DENABLE_TOOLS=0 -DCONFIG_AV1_HIGHBITDEPTH=0 -DCONFIG_WEBM_IO=0
  cmake --build "$tmp/$1" -j"$(sysctl -n hw.ncpu)" --target aom
}
build macos-arm64 -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15
build macos-x86_64 -DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15 -DAOM_TARGET_CPU=generic
ios=(-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=16.4)
build ios "${ios[@]}" -DCMAKE_OSX_ARCHITECTURES=arm64 -DAOM_TARGET_CPU=arm64
build ios-simulator-arm64 "${ios[@]}" -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_ARCHITECTURES=arm64 -DAOM_TARGET_CPU=arm64
build ios-simulator-x86_64 "${ios[@]}" -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_ARCHITECTURES=x86_64 -DAOM_TARGET_CPU=generic

mkdir -p "$tmp/macos" "$tmp/ios-simulator" "$out/include/aom"
lipo -create "$tmp/macos-arm64/libaom.a" "$tmp/macos-x86_64/libaom.a" -output "$tmp/macos/libaom.a"
lipo -create "$tmp/ios-simulator-arm64/libaom.a" "$tmp/ios-simulator-x86_64/libaom.a" -output "$tmp/ios-simulator/libaom.a"
xcodebuild -create-xcframework -output "$out/libaom.xcframework" \
  -library "$tmp/macos/libaom.a" -library "$tmp/ios/libaom.a" -library "$tmp/ios-simulator/libaom.a"
cp "$tmp"/aom/aom/*.h "$out/include/aom/"
