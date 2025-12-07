#!/bin/bash
set -e

echo "=========================================="
echo "Custom Linux ISO Creation Script"
echo "=========================================="

# Configuration
ROOTFS_IMG="$HOME/myos/rootfs.img"
KERNEL_DIR="$HOME/my_exp/releases/linux-6.12.60"
WORK_DIR="$HOME/myos-iso-build"
ISO_NAME="my-custom-linux.iso"
ISO_OUTPUT="$HOME/myos/$ISO_NAME"

# Check prerequisites
echo ""
echo "[1/9] Checking prerequisites..."

if [ ! -f "$ROOTFS_IMG" ]; then
    echo "ERROR: rootfs.img not found at $ROOTFS_IMG"
    exit 1
fi

if [ ! -f "$KERNEL_DIR/arch/x86/boot/bzImage" ]; then
    echo "ERROR: Kernel bzImage not found at $KERNEL_DIR/arch/x86/boot/bzImage"
    exit 1
fi

echo "✓ All prerequisites found"

# Install required tools
echo ""
echo "[2/9] Installing required tools..."
sudo pacman -S --needed --noconfirm grub libisoburn squashfs-tools busybox cpio

# Create initramfs
echo ""
echo "[3/9] Creating initramfs with SquashFS support..."

rm -rf ~/myos-initramfs
mkdir -p ~/myos-initramfs
cd ~/myos-initramfs

# Create directory structure
mkdir -p bin sbin lib lib64 proc sys dev mnt/cdrom mnt/squashfs newroot

# Copy busybox
cp /usr/bin/busybox bin/

# Create busybox symlinks
cd bin
for cmd in sh mount umount switch_root mkdir sleep cp ls cat echo; do
    ln -sf busybox $cmd 2>/dev/null || true
done
cd ..

# Create init script that handles SquashFS
cat > init << 'INITEOF'
#!/bin/sh

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "=========================================="
echo "Loading Custom Linux OS..."
echo "=========================================="
sleep 2

# Create mount points
mkdir -p /mnt/cdrom /mnt/squashfs /newroot

# Find and mount the ISO
echo "Searching for ISO device..."
FOUND=0
for device in /dev/sr0 /dev/vda /dev/sda /dev/sdb /dev/hda; do
    if [ -b "$device" ]; then
        echo "Trying $device..."
        if mount -t iso9660 -o ro "$device" /mnt/cdrom 2>/dev/null; then
            if [ -f /mnt/cdrom/live/filesystem.squashfs ]; then
                echo "✓ Found filesystem on $device"
                FOUND=1
                break
            fi
            umount /mnt/cdrom 2>/dev/null
        fi
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "ERROR: Could not find filesystem.squashfs"
    echo "Dropping to emergency shell..."
    exec /bin/sh
fi

# Mount the SquashFS
echo "Mounting SquashFS filesystem..."
if ! mount -t squashfs /mnt/cdrom/live/filesystem.squashfs /mnt/squashfs; then
    echo "ERROR: Failed to mount SquashFS"
    echo "Dropping to emergency shell..."
    exec /bin/sh
fi

echo "✓ SquashFS mounted successfully"

# Create overlay filesystem (faster, uses less RAM)
echo "Setting up overlay filesystem..."
mkdir -p /overlay /newroot

# Mount tmpfs for writable layer FIRST
mount -t tmpfs -o size=2G tmpfs /overlay

# NOW create the directories inside the mounted tmpfs
mkdir -p /overlay/upper /overlay/work

echo "Overlay structure created, attempting mount..."

# Create overlay combining read-only squashfs + writable tmpfs
if mount -t overlay overlay \
    -o lowerdir=/mnt/squashfs,upperdir=/overlay/upper,workdir=/overlay/work \
    /newroot; then
    echo "✓ Overlay filesystem mounted successfully"
else
    echo "ERROR: Overlay mount failed, falling back to RAM copy"
    umount /overlay 2>/dev/null
    
    # Fallback: copy to RAM
    mount -t tmpfs -o size=4G tmpfs /newroot
    echo "Copying system to RAM (please wait)..."
    cp -a /mnt/squashfs/. /newroot/
    echo "✓ System copied to RAM"
fi

echo "✓ Filesystem ready"

# Keep ISO and squashfs mounted (needed for overlay)
echo "Preparing to switch root..."
umount /proc 2>/dev/null || true
umount /sys 2>/dev/null || true
umount /dev 2>/dev/null || true

# Switch to the real root
echo "Switching to root filesystem..."
echo "=========================================="
exec switch_root /newroot /lib/systemd/systemd
INITEOF

chmod +x init

# Package the initramfs
echo "Packaging initramfs..."
find . -print0 | cpio --null -o --format=newc | gzip -9 > ~/myos/initramfs.img

cd ~
echo "✓ Initramfs created ($(du -h ~/myos/initramfs.img | cut -f1))"

# Clean and create work directory
echo ""
echo "[4/9] Preparing workspace..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/iso/boot/grub"
mkdir -p "$WORK_DIR/iso/live"

echo ""
echo "[5/9] Creating compressed SquashFS from rootfs..."

# Mount rootfs temporarily
TEMP_MOUNT="/tmp/rootfs-mount-$$"
sudo mkdir -p "$TEMP_MOUNT"
sudo mount -o loop,ro "$ROOTFS_IMG" "$TEMP_MOUNT"

# Create SquashFS (this compresses the filesystem)
echo "This may take several minutes..."
sudo mksquashfs "$TEMP_MOUNT" "$WORK_DIR/iso/live/filesystem.squashfs" \
    -comp xz \
    -b 1M \
    -Xdict-size 100% \
    -e boot \
    -noappend

SQUASH_SIZE=$(du -h "$WORK_DIR/iso/live/filesystem.squashfs" | cut -f1)
echo "✓ SquashFS created ($SQUASH_SIZE)"

# Unmount
sudo umount "$TEMP_MOUNT"
sudo rmdir "$TEMP_MOUNT"

echo ""
echo "[6/9] Copying kernel..."
cp "$KERNEL_DIR/arch/x86/boot/bzImage" "$WORK_DIR/iso/boot/vmlinuz"
echo "✓ Kernel copied"

echo ""
echo "[7/9] Copying initramfs..."
cp ~/myos/initramfs.img "$WORK_DIR/iso/boot/initramfs.img"
echo "✓ Initramfs copied"

echo ""
echo "[8/9] Creating GRUB bootloader configuration..."
cat > "$WORK_DIR/iso/boot/grub/grub.cfg" << 'GRUBEOF'
set timeout=5
set default=0

menuentry "My Custom Linux - Live Boot" {
    linux /boot/vmlinuz quiet splash
    initrd /boot/initramfs.img
    boot
}

menuentry "My Custom Linux - Verbose Boot" {
    linux /boot/vmlinuz
    initrd /boot/initramfs.img
    boot
}

menuentry "My Custom Linux - Safe Mode" {
    linux /boot/vmlinuz nomodeset
    initrd /boot/initramfs.img
    boot
}
GRUBEOF

echo "✓ GRUB configuration created"

echo ""
echo "[9/9] Building bootable ISO..."
cd "$WORK_DIR"

grub-mkrescue -o "$ISO_OUTPUT" iso/ --compress=xz

if [ ! -f "$ISO_OUTPUT" ]; then
    echo "ERROR: ISO creation failed!"
    exit 1
fi

ISO_SIZE=$(du -h "$ISO_OUTPUT" | cut -f1)

echo ""
echo "=========================================="
echo "✓ ISO CREATION SUCCESSFUL!"
echo "=========================================="
echo ""
echo "ISO Location: $ISO_OUTPUT"
echo "ISO Size: $ISO_SIZE"
echo ""
echo "To test the ISO:"
echo "  qemu-system-x86_64 -cdrom $ISO_OUTPUT -m 4G -enable-kvm"
echo ""
echo "Or in virt-manager:"
echo "  1. Create new VM"
echo "  2. Choose 'Import existing disk image'"
echo "  3. Select the ISO as CD-ROM"
echo "  4. Boot!"
echo ""
echo "Login credentials:"
echo "  Username: ashu"
echo "  Password: ashu"
echo ""
echo "=========================================="

# Cleanup prompt
echo ""
read -p "Clean up build directory ($WORK_DIR)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$WORK_DIR"
    rm -rf ~/myos-initramfs
    echo "✓ Cleaned up build files"
fi

echo ""
echo "Done! Your ISO is ready at: $ISO_OUTPUT"
