#!/bin/bash
set -e

echo "========================================"
echo "Arch Linux Rootfs Setup for Custom ISO"
echo "========================================"

# Configuration
ROOTFS_SIZE="8G"
ROOTFS_IMG="$HOME/myos/rootfs.img"
MOUNT_POINT="/mnt/rootfs"
KERNEL_DIR="$HOME/kernel-rebuild/linux-6.12.60"
USERNAME="ashu"

echo ""
echo "[1/10] Creating rootfs image ($ROOTFS_SIZE)..."
mkdir -p ~/myos
cd ~/myos

if [ -f "$ROOTFS_IMG" ]; then
    read -p "rootfs.img already exists. Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$ROOTFS_IMG"
    else
        echo "Using existing rootfs.img"
    fi
fi

if [ ! -f "$ROOTFS_IMG" ]; then
    truncate -s "$ROOTFS_SIZE" "$ROOTFS_IMG"
    mkfs.ext4 -L archroot "$ROOTFS_IMG"
    echo "✓ Created and formatted rootfs.img"
else
    echo "✓ Using existing rootfs.img"
fi

echo ""
echo "[2/10] Mounting rootfs..."
sudo mkdir -p "$MOUNT_POINT"
sudo mount -o loop "$ROOTFS_IMG" "$MOUNT_POINT"
echo "✓ Mounted at $MOUNT_POINT"

echo ""
echo "[3/10] Installing base Arch system (this takes 5-10 minutes)..."
sudo pacstrap -K "$MOUNT_POINT" \
    base \
    base-devel \
    linux-firmware \
    networkmanager \
    vim \
    nano \
    sudo \
    git

echo ""
echo "[4/10] Generating fstab..."
sudo genfstab -U "$MOUNT_POINT" | sudo tee "$MOUNT_POINT/etc/fstab"

echo ""
echo "[5/10] Setting hostname..."
echo "myos" | sudo tee "$MOUNT_POINT/etc/hostname"

echo ""
echo "[6/10] Installing custom kernel modules..."
if [ -d "$KERNEL_DIR" ]; then
    cd "$KERNEL_DIR"
    sudo make modules_install INSTALL_MOD_PATH="$MOUNT_POINT"
    echo "✓ Kernel modules installed"
else
    echo "⚠ Kernel directory not found at $KERNEL_DIR"
    echo "Skipping module installation. Build kernel first!"
fi

echo ""
echo "[7/10] Copying custom kernel..."
if [ -f "$KERNEL_DIR/arch/x86/boot/bzImage" ]; then
    sudo cp "$KERNEL_DIR/arch/x86/boot/bzImage" "$MOUNT_POINT/boot/vmlinuz-custom"
    echo "✓ Kernel copied to /boot/vmlinuz-custom"
else
    echo "⚠ Kernel bzImage not found! Build kernel first."
fi

echo ""
echo "[8/10] Setting up chroot environment..."
sudo mount --bind /dev "$MOUNT_POINT/dev"
sudo mount --bind /dev/pts "$MOUNT_POINT/dev/pts"
sudo mount --bind /proc "$MOUNT_POINT/proc"
sudo mount --bind /sys "$MOUNT_POINT/sys"
sudo mount --bind /run "$MOUNT_POINT/run"

echo ""
echo "[9/10] Configuring system inside chroot..."

# Create configuration script to run inside chroot
sudo tee "$MOUNT_POINT/tmp/setup.sh" > /dev/null << 'CHROOT_EOF'
#!/bin/bash
set -e

echo "=== Inside chroot setup ==="

# Set root password
echo "Setting root password..."
echo "root:root" | chpasswd

# Create user
echo "Creating user: ashu..."
useradd -m -G wheel,audio,video,storage,power -s /bin/bash ashu
echo "ashu:ashu" | chpasswd

# Configure sudo
echo "Configuring sudo..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Enable NetworkManager
echo "Enabling NetworkManager..."
systemctl enable NetworkManager

# Set timezone (change if needed)
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime

# Generate locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Install Hyprland and essentials
echo "Installing Hyprland and desktop packages..."
pacman -Syu --noconfirm
pacman -S --noconfirm \
    hyprland \
    xdg-desktop-portal-hyprland \
    waybar \
    kitty \
    wofi \
    polkit \
    seatd \
    pipewire pipewire-pulse wireplumber \
    grim slurp \
    ttf-dejavu ttf-liberation noto-fonts \
    firefox \
    git \
    wget \
    curl

# Enable seatd for Hyprland
systemctl enable seatd

echo "=== Chroot setup complete ==="
CHROOT_EOF

sudo chmod +x "$MOUNT_POINT/tmp/setup.sh"

echo "Running configuration inside chroot..."
sudo chroot "$MOUNT_POINT" /tmp/setup.sh

echo ""
echo "[10/10] Installing Hyprland config (hyprconf)..."

# Create script to install hyprconf as user ashu
sudo tee "$MOUNT_POINT/tmp/hyprconf-setup.sh" > /dev/null << 'HYPR_EOF'
#!/bin/bash
set -e

cd /home/ashu

# Clone hyprconf if not exists
if [ ! -d "hyprconf-install" ]; then
    git clone https://github.com/shell-ninja/hyprconf-install.git
fi

cd hyprconf-install
chmod +x install.sh

# Run as user ashu
sudo -u ashu bash install.sh

echo "Hyprconf installed!"
HYPR_EOF

sudo chmod +x "$MOUNT_POINT/tmp/hyprconf-setup.sh"

read -p "Install Hyprland config (hyprconf)? This takes 2-5 minutes (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing hyprconf..."
    sudo chroot "$MOUNT_POINT" /tmp/hyprconf-setup.sh
    echo "✓ Hyprconf installed"
else
    echo "Skipped hyprconf installation"
fi

echo ""
echo "Cleaning up chroot mounts..."
sudo umount "$MOUNT_POINT/dev/pts" 2>/dev/null || true
sudo umount "$MOUNT_POINT/dev" 2>/dev/null || true
sudo umount "$MOUNT_POINT/proc" 2>/dev/null || true
sudo umount "$MOUNT_POINT/sys" 2>/dev/null || true
sudo umount "$MOUNT_POINT/run" 2>/dev/null || true

echo ""
echo "Unmounting rootfs..."
sudo umount "$MOUNT_POINT"

echo ""
echo "========================================"
echo "✓ Rootfs setup complete!"
echo "========================================"
echo ""
echo "Image location: $ROOTFS_IMG"
echo "Size: $(du -h $ROOTFS_IMG | cut -f1)"
echo ""
echo "Login credentials:"
echo "  root / root"
echo "  ashu / ashu"
echo ""
echo "Next steps:"
echo "1. Test in VM: virt-manager with direct kernel boot"
echo "2. Create ISO for distribution"
echo "========================================"
