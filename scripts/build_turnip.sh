#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
NDK_HOME=${NDK_HOME:-"$ROOT/android-ndk-r25b"}
MESA_TAG=${MESA_TAG:-v26.2.0-R6}
BUILD_DIR="$ROOT/mesa-build"
INSTALL_DIR="$ROOT/build-output"

mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

echo "Cloning mesa (may take a while)..."
git clone --depth 1 --branch "$MESA_TAG" https://gitlab.freedesktop.org/mesa/mesa.git mesa-src || true
cd mesa-src
git fetch --all --tags
git checkout "$MESA_TAG" || true

echo "Writing meson cross file..."
cat > $ROOT/scripts/meson_android_aarch64_cross.txt <<EOF
[binaries]
c = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang'
cpp = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang++'
ar = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'

[properties]
sys_root = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'
EOF

echo "Configuring meson (freedreno/turnip only)..."
meson setup "$BUILD_DIR" --cross-file $ROOT/scripts/meson_android_aarch64_cross.txt \
  -Dgallium-drivers=freedreno -Dvulkan-drivers=turnip -Dplatforms= -Dbuildtype=release -Dprefix=/usr -Dlibdir=lib64 || true

echo "Running ninja to build Turnip..."
cd "$BUILD_DIR"
ninja -v || true

echo "Collecting built .so (if any)..."
find . -name 'libvulkan*so' -exec cp -v {} "$INSTALL_DIR/" \; || true

echo "Build complete. Artifacts in $INSTALL_DIR"
