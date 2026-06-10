#!/usr/bin/env bash
set -euo pipefail

# Simple installer for Turnip driver on a device with root access (or emulator)
# Usage: ./install_turnip.sh [DEVICE_SERIAL]
# If device is not rooted, see README for non-root testing instructions.

DEVICE=${1:-}
ADB=(adb)
[ -n "$DEVICE" ] && ADB=(adb -s "$DEVICE")

LIB_SRC="Turnip_v26.2.0-R6/libvulkan_freedreno.so"
ICD_SRC="Turnip.freedreno.icd.json"

DEVICE_LIB_DIR="/vendor/lib64"
DEVICE_ICD_DIR="/vendor/etc/vulkan/icd.d"

echo "Pushing files to device temporary folder..."
"${ADB[@]}" push "$LIB_SRC" /data/local/tmp/
"${ADB[@]}" push "$ICD_SRC" /data/local/tmp/

echo "Attempting to copy into system vendor locations (requires root)..."
"${ADB[@]}" shell su -c "mount -o remount,rw /vendor || true"
"${ADB[@]}" shell su -c "cp /data/local/tmp/$(basename "$LIB_SRC") $DEVICE_LIB_DIR/"
"${ADB[@]}" shell su -c "cp /data/local/tmp/$(basename "$ICD_SRC") $DEVICE_ICD_DIR/"
"${ADB[@]}" shell su -c "chmod 644 $DEVICE_LIB_DIR/$(basename "$LIB_SRC") $DEVICE_ICD_DIR/$(basename "$ICD_SRC")"

echo "Done. Reboot device or restart the app to pick up the new ICD."

cat <<'USAGE'
Non-root testing (alternative):
- For emulators or rooted images the above will install to /vendor.
- For non-rooted devices, place the driver and ICD inside the app's data and set
  the environment variable VK_ICD_FILENAMES to point to the full path of the ICD
  before launching the app (requires launching app from adb shell with env).
USAGE
