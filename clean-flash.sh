#!/usr/bin/env bash
set -e

DEVICE=/dev/sdc
IMAGE_PATH=$(find result/sd-image/ -name '*.img.zst' | head -n 1)

echo "Flashing $IMAGE_PATH to $DEVICE..."
zstdcat "$IMAGE_PATH" | dd of="$DEVICE" bs=4M status=progress
sync
sleep 5

echo "Installing bootloader..."
/nix/store/v7xlnjmn6phd8n98rfmp5gq8na8fv333-odroid-xu3-bootloader-armv7l-unknown-linux-gnueabihf-unstable-2015-12-04/bin/sd_fuse-xu3 "$DEVICE"
sync
sleep 2

echo "Patching U-Boot script..."
mkdir -p /mnt/sdc
mount ${DEVICE}2 /mnt/sdc || { sleep 5; blockdev --rereadpt $DEVICE || true; sleep 2; mount ${DEVICE}2 /mnt/sdc; }

cat > boot.cmd <<'INNER_EOF'
setenv kernel_addr_r 0x42000000
setenv fdt_addr_r 0x45000000
setenv ramdisk_addr_r 0x47000000
setenv scriptaddr 0x46500000
echo 'Loading extlinux with fixed addresses...'
sysboot mmc 2:2 any ${scriptaddr} /boot/extlinux/extlinux.conf
INNER_EOF

nix-shell -p ubootTools --run 'mkimage -C none -A arm -T script -d boot.cmd boot.scr'
cp boot.scr /mnt/sdc/boot.scr
cp boot.scr /mnt/sdc/boot/boot.scr

echo "Unmounting and syncing..."
sync
umount /mnt/sdc
sync
echo "ALL DONE. YOU CAN SAFELY EJECT THE SD CARD."
