#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
NDK_HOME=${NDK_HOME:-"$ROOT/android-ndk-r25b"}
MESA_TAG=${MESA_TAG:-v26.2.0-R6}
BUILD_DIR="$ROOT/mesa-build"
INSTALL_DIR="$ROOT/build-output"

mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

echo "Cloning mesa (may take a while)..."
git clone https://gitlab.freedesktop.org/mesa/mesa.git mesa-src || true
cd mesa-src
git fetch --all --tags || true

# Try to checkout requested tag/branch, otherwise use main for latest development version
echo "Attempting to checkout: $MESA_TAG"
if git rev-parse --verify --quiet "$MESA_TAG" >/dev/null 2>&1; then
  echo "✓ Found local reference: $MESA_TAG"
  git checkout "$MESA_TAG" || true
elif git ls-remote --exit-code --heads origin "$MESA_TAG" >/dev/null 2>&1; then
  echo "✓ Found remote branch: $MESA_TAG"
  git checkout -b "$MESA_TAG" "origin/$MESA_TAG" || true
elif git ls-remote --exit-code --tags origin "$MESA_TAG" >/dev/null 2>&1; then
  echo "✓ Found remote tag: $MESA_TAG"
  git checkout "$MESA_TAG" || true
else
  echo "✗ Tag/branch '$MESA_TAG' not found in upstream"
  echo "✓ Falling back to main development branch for latest Turnip"
  git fetch origin main || true
  git checkout main || git checkout master || true
fi

echo "Writing meson cross file with ultra-aggressive A735 tuning..."
cat > $ROOT/scripts/meson_android_aarch64_cross.txt <<EOF
[binaries]
c = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang'
cpp = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang++'
ar = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'

[properties]
sys_root = '${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot'
c_args = ['-Ofast', '-march=armv8.2-a+crypto', '-mtune=cortex-a76', '-mcpu=cortex-a76', '-fvectorize', '-ftree-vectorize', '-ftree-loop-distribution', '-funroll-loops', '-ffast-math', '-ffp-contract=fast', '-fomit-frame-pointer', '-ffunction-sections', '-fdata-sections', '-fno-math-errno']
c_link_args = ['-Ofast', '-fomit-frame-pointer', '-Wl,--gc-sections', '-flto=thin']
cpp_args = ['-Ofast', '-march=armv8.2-a+crypto', '-mtune=cortex-a76', '-mcpu=cortex-a76', '-fvectorize', '-ftree-vectorize', '-ftree-loop-distribution', '-funroll-loops', '-ffast-math', '-ffp-contract=fast', '-fomit-frame-pointer', '-ffunction-sections', '-fdata-sections', '-fno-math-errno']
cpp_link_args = ['-Ofast', '-fomit-frame-pointer', '-Wl,--gc-sections', '-flto=thin']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'
EOF

echo "Configuring meson with ultra-aggressive A735 and freedreno tuning..."
cd "$ROOT"
# Ensure build dir doesn't exist for clean setup
rm -rf "$BUILD_DIR" || true
mkdir -p "$BUILD_DIR"

# Verify mesa-src/meson.build exists before proceeding
if [ ! -f "mesa-src/meson.build" ]; then
  echo "ERROR: mesa-src/meson.build not found. Mesa checkout may have failed."
  exit 1
fi

meson setup "$BUILD_DIR" mesa-src --cross-file $ROOT/scripts/meson_android_aarch64_cross.txt \
  -Dgallium-drivers=freedreno \
  -Dvulkan-drivers=turnip \
  -Dplatforms= \
  -Dbuildtype=release \
  -Db_ndebug=true \
  -Db_lto=thin \
  -Dllvm=enabled \
  -Dshared-llvm=false \
  -Dprefix=/usr \
  -Dlibdir=lib64 \
  -Dglx=disabled \
  -Degl=enabled \
  -Dgles1=disabled \
  -Dgles2=enabled \
  -Dvalgrind=disabled \
  -Ddri3=disabled \
  -Dxvmc=disabled \
  -Dvulkan-strict-layer-ordering=true \
  -Dvulkan-icd-dir=/system/lib64/hw || true

echo "Running ninja to build Turnip..."
cd "$BUILD_DIR"
ninja -j$(nproc) turnip_libvulkan 2>&1 | tail -50 || echo "Ninja build failed or incomplete"

echo "Collecting built .so (if any)..."
find "$BUILD_DIR" -name 'libvulkan*so*' -type f -exec cp -v {} "$INSTALL_DIR/" \; || true

cd "$ROOT"
echo "Build complete. Artifacts in $INSTALL_DIR"
ls -lah "$INSTALL_DIR" || true
