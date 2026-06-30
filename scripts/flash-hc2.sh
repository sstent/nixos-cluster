#!/usr/bin/env bash
set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <block-device>"
    echo "Example: $0 /dev/mmcblk0"
    echo "WARNING: THIS WILL OVERWRITE THE SPECIFIED DEVICE!"
    exit 1
fi

DEVICE=$1
IMAGE_PATH=$2

if [ -z "$IMAGE_PATH" ]; then
    # Look for the generated image
    IMAGE_PATH=$(find result/sd-image/ -name "*.img.zst" | head -n 1)
fi

if [ -z "$IMAGE_PATH" ]; then
    echo "Error: No .img.zst found in result/sd-image/"
    echo "Run 'nix build .#nixosConfigurations.sd-odroid-hc2.config.system.build.sdImage' first."
    exit 1
fi

echo "Found image: $IMAGE_PATH"
echo "Flashing to $DEVICE..."

# Flash the image
zstdcat "$IMAGE_PATH" | sudo dd of="$DEVICE" bs=4M status=progress
sudo sync

echo "Image flashed. Now installing Odroid HC2 (XU3) bootloader..."

# Ensure we have sd_fuse-xu3 available
if ! command -v sd_fuse-xu3 &> /dev/null; then
    echo "sd_fuse-xu3 not found in PATH. Attempting to run via nix-shell..."
    nix-shell -p odroid-xu3-bootloader --run "sudo sd_fuse-xu3 $DEVICE"
else
    sudo sd_fuse-xu3 "$DEVICE"
fi

echo "Bootloader installed successfully."
echo "You can now safely eject $DEVICE and boot your Odroid HC2."
