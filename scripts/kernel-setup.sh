#!/bin/bash
set -e  # Exit on any error

echo "======================================"
echo "Kernel 6.12.60 Setup for ISO Creation"
echo "======================================"
echo ""

# Create working directory
WORK_DIR="$HOME/kernel-rebuild"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "[1/6] Downloading kernel 6.12.60..."
if [ ! -f "linux-6.12.60.tar.xz" ]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.60.tar.xz
    echo "Download complete!"
else
    echo "Kernel already downloaded, skipping..."
fi

echo ""
echo "[2/6] Extracting kernel..."
if [ ! -d "linux-6.12.60" ]; then
    tar -xf linux-6.12.60.tar.xz
    echo "Extraction complete!"
else
    echo "Kernel already extracted, skipping..."
fi

cd linux-6.12.60

echo ""
echo "[3/6] Configuring kernel with all necessary options for ISO..."
echo "This will enable: ISO9660, SquashFS, loop devices, and all essential drivers"

# Start with default config
make defconfig

# Enable all necessary options for VM-only ISO
cat >> .config << 'EOF'

# ===== CRITICAL FOR ISO BOOTING =====
CONFIG_ISO9660_FS=y
CONFIG_JOLIET=y
CONFIG_ZISOFS=y
CONFIG_UDF_FS=y

# ===== SQUASHFS (for compressed filesystem) =====
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_FILE_CACHE=y
CONFIG_SQUASHFS_DECOMP_SINGLE=y
CONFIG_SQUASHFS_XATTR=y
CONFIG_SQUASHFS_ZLIB=y
CONFIG_SQUASHFS_LZ4=y
CONFIG_SQUASHFS_LZO=y
CONFIG_SQUASHFS_XZ=y
CONFIG_SQUASHFS_ZSTD=y

# ===== OVERLAY FILESYSTEM (for live ISO) =====
CONFIG_OVERLAY_FS=y
CONFIG_OVERLAY_FS_REDIRECT_DIR=y
CONFIG_OVERLAY_FS_REDIRECT_ALWAYS_FOLLOW=y
CONFIG_OVERLAY_FS_INDEX=y
CONFIG_OVERLAY_FS_XINO_AUTO=y
CONFIG_OVERLAY_FS_METACOPY=y

# ===== BLOCK DEVICES =====
CONFIG_BLK_DEV_LOOP=y
CONFIG_BLK_DEV_RAM=y
CONFIG_BLK_DEV_RAM_SIZE=65536
CONFIG_BLK_DEV_INITRD=y

# ===== INITRAMFS SUPPORT =====
CONFIG_RD_GZIP=y
CONFIG_RD_BZIP2=y
CONFIG_RD_LZMA=y
CONFIG_RD_XZ=y
CONFIG_RD_LZO=y
CONFIG_RD_LZ4=y
CONFIG_RD_ZSTD=y

# ===== SCSI SUPPORT (for VM virtual disks) =====
CONFIG_SCSI=y
CONFIG_BLK_DEV_SD=y
CONFIG_BLK_DEV_SR=y
CONFIG_CHR_DEV_SG=y
CONFIG_SCSI_CONSTANTS=y

# ===== ATA (minimal for VMs) =====
CONFIG_ATA=y
CONFIG_SATA_AHCI=y
CONFIG_ATA_PIIX=y

# ===== FILESYSTEMS =====
CONFIG_EXT4_FS=y
CONFIG_EXT4_FS_POSIX_ACL=y
CONFIG_EXT4_FS_SECURITY=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_CONFIGFS_FS=y

# ===== VIRTUALIZATION (VM-specific drivers) =====
CONFIG_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_PCI_LEGACY=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_CONSOLE=y
CONFIG_VIRTIO_BALLOON=y
CONFIG_VIRTIO_INPUT=y
CONFIG_HW_RANDOM_VIRTIO=y
CONFIG_DRM_VIRTIO_GPU=y
CONFIG_VIRTIO_FS=y

# ===== NETWORK (VM virtual NICs) =====
CONFIG_NETDEVICES=y
CONFIG_ETHERNET=y
CONFIG_NET_VENDOR_INTEL=y
CONFIG_E1000=y
CONFIG_E1000E=y
CONFIG_NET_VENDOR_REALTEK=y
CONFIG_R8169=y

# ===== SYSTEMD REQUIREMENTS =====
CONFIG_CGROUPS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_SCHED=y
CONFIG_MEMCG=y
CONFIG_BLK_CGROUP=y
CONFIG_NAMESPACES=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
CONFIG_KEYS=y
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
CONFIG_FHANDLE=y
CONFIG_EVENTFD=y
CONFIG_EPOLL=y
CONFIG_SIGNALFD=y
CONFIG_TIMERFD=y
CONFIG_INOTIFY_USER=y
CONFIG_FANOTIFY=y
CONFIG_AUTOFS_FS=y

# ===== DKMS & MODULE SUPPORT =====
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MODULE_FORCE_UNLOAD=y
CONFIG_MODVERSIONS=y
CONFIG_MODULE_SRCVERSION_ALL=y
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y

# ===== COMPRESSION (all formats) =====
CONFIG_ZLIB_INFLATE=y
CONFIG_ZLIB_DEFLATE=y
CONFIG_LZO_COMPRESS=y
CONFIG_LZO_DECOMPRESS=y
CONFIG_LZ4_COMPRESS=y
CONFIG_LZ4_DECOMPRESS=y
CONFIG_XZ_DEC=y
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y

# ===== FIRMWARE LOADING =====
CONFIG_FW_LOADER=y
CONFIG_FIRMWARE_IN_KERNEL=y

# ===== GRAPHICS (VM GPU) =====
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_FB=y
CONFIG_FB_MODE_HELPERS=y
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y
CONFIG_DRM_VIRTIO_GPU=y
CONFIG_DRM_BOCHS=y

# ===== INPUT =====
CONFIG_INPUT=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_INPUT_MOUSE=y
CONFIG_INPUT_EVDEV=y

# ===== MISC ESSENTIAL =====
CONFIG_PRINTK=y
CONFIG_BUG=y
CONFIG_ELF_CORE=y
CONFIG_PCI=y
CONFIG_PCI_MSI=y
CONFIG_ACPI=y

EOF

# Run olddefconfig to resolve dependencies
make olddefconfig

echo ""
echo "[4/6] Verifying critical options are enabled..."
REQUIRED_OPTIONS=(
    "CONFIG_ISO9660_FS"
    "CONFIG_SQUASHFS"
    "CONFIG_BLK_DEV_LOOP"
    "CONFIG_EXT4_FS"
    "CONFIG_DEVTMPFS"
)

ALL_GOOD=true
for opt in "${REQUIRED_OPTIONS[@]}"; do
    if grep -q "^${opt}=y" .config; then
        echo "✓ $opt enabled"
    else
        echo "✗ $opt NOT enabled (this is a problem!)"
        ALL_GOOD=false
    fi
done

if [ "$ALL_GOOD" = false ]; then
    echo ""
    echo "ERROR: Some required options are not enabled!"
    echo "You may need to run 'make menuconfig' manually."
    exit 1
fi

echo ""
echo "All critical options verified!"

echo ""
read -p "[5/6] Build kernel now? This will take 10-60 minutes depending on CPU (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Building kernel with $(nproc) CPU cores..."
    make -j$(nproc)
    
    echo ""
    echo "[6/6] Kernel built successfully!"
    echo ""
    echo "Kernel location: $(pwd)/arch/x86/boot/bzImage"
    echo "Kernel modules: Use 'sudo make modules_install' to install"
    echo ""
    echo "======================================"
    echo "Next steps:"
    echo "1. Create your rootfs"
    echo "2. Copy kernel: cp arch/x86/boot/bzImage /path/to/rootfs/boot/"
    echo "3. Install modules: INSTALL_MOD_PATH=/path/to/rootfs make modules_install"
    echo "4. Create ISO"
    echo "======================================"
else
    echo ""
    echo "Kernel configured but not built."
    echo "To build later, run: cd $WORK_DIR/linux-6.12.60 && make -j$(nproc)"
fi

echo ""
echo "Configuration saved at: $(pwd)/.config"
echo "You can review/modify with: make menuconfig"
