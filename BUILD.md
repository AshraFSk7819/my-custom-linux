# Building Custom Linux from Scratch

Complete guide to building this custom Linux distribution with Hyprland desktop environment.

## Prerequisites

### Host System Requirements
- **OS:** Arch Linux (or Arch-based distribution)
- **Disk Space:** 30GB+ free
- **RAM:** 8GB minimum, 16GB recommended
- **CPU:** Multi-core recommended for faster kernel compilation

### Install Required Tools
```bash
sudo pacman -S --needed \
    base-devel \
    git \
    wget \
    curl \
    arch-install-scripts \
    grub \
    libisoburn \
    squashfs-tools \
    busybox \
    cpio \
    qemu-full \
    virt-manager
```

---

## Build Process Overview

The build process consists of 4 main steps:
1. **Build Custom Kernel** (~30-60 minutes)
2. **Create Root Filesystem** (~15-20 minutes)
3. **Customize Hyprland** (in VM, ~10-30 minutes)
4. **Generate Bootable ISO** (~5-10 minutes)

---

## Step 1: Build Custom Kernel

### 1.1 Run Kernel Setup Script

```bash
cd scripts
chmod +x kernel-setup.sh
./kernel-setup.sh
```

**What this does:**
- Downloads Linux kernel 6.12.60
- Configures kernel with necessary options for ISO boot (SquashFS, Overlay FS, VirtIO drivers)
- Compiles the kernel (this takes 30-60 minutes)
- Installs kernel modules

**Expected output:**
```
Kernel location: ~/kernel-rebuild/linux-6.12.60/arch/x86/boot/bzImage
```

### 1.2 Verify Kernel Built Successfully

```bash
ls -lh ~/kernel-rebuild/linux-6.12.60/arch/x86/boot/bzImage
```

You should see a ~8-10MB file.

---

## Step 2: Create Root Filesystem

### 2.1 Run Rootfs Setup Script

```bash
chmod +x rootfs-setup.sh
./rootfs-setup.sh
```

**What this does:**
- Creates an 8GB ext4 disk image
- Installs Arch Linux base system
- Installs Hyprland and essential packages
- Installs your custom kernel modules
- Creates user `ashu` with password `ashu`
- Sets root password to `root`

**Expected output:**
```
✓ Rootfs setup complete!
Image location: ~/myos/rootfs.img
```

### 2.2 Verify Rootfs Size

```bash
sudo mount -o loop ~/myos/rootfs.img /mnt
sudo du -sh /mnt
sudo umount /mnt
```

Should be around 3-4GB of actual data.

---

## Step 3: Customize Hyprland Desktop

### 3.1 Boot into VM for Customization

Create a new VM in virt-manager:

1. **Open virt-manager**
   ```bash
   virt-manager
   ```

2. **Create New VM:**
   - Choose "Import existing disk image"
   - Select: `~/myos/rootfs.img`
   - OS type: Linux → Arch Linux
   - RAM: 4096 MB
   - CPUs: 2-4 cores

3. **Configure Direct Kernel Boot:**
   - Before finishing, check **"Customize configuration before install"**
   - Go to **Boot Options**
   - Enable **"Enable direct kernel boot"**
   - Fill in:
     - **Kernel path:** `/home/YOUR_USERNAME/kernel-rebuild/linux-6.12.60/arch/x86/boot/bzImage`
     - **Initrd:** Leave empty
     - **Kernel args:** `root=/dev/vda rw loglevel=3 console=tty0`

4. **Set Disk and Video:**
   - **Disk:** Bus type = VirtIO
   - **Video:** Model = VirtIO

5. **Start the VM**

### 3.2 Login and Start Hyprland

```bash
# Login credentials
Username: ashu
Password: ashu

# Hyprland won't auto-start, manually run:
Hyprland
```

**Note:** You'll see a black screen initially - this is normal. Hyprland will start.

### 3.3 Customize Your Desktop

Now you can:
- Configure Hyprland (`~/.config/hypr/hyprland.conf`)
- Install your dotfiles
- Add wallpapers to `~/Pictures/`
- Install additional packages with `sudo pacman -S <package>`
- Set up themes, fonts, icons

**Important:** Any changes you make here will be included in the final ISO!

### 3.4 Clean Up Before ISO Creation

Before shutting down the VM:

```bash
# Clean package cache to reduce size
sudo rm -rf /var/cache/pacman/pkg/*

# Clean logs
sudo rm -rf /var/log/*

# Clean temporary files
sudo rm -rf /tmp/*
sudo rm -rf ~/.cache/*

# Shutdown
sudo shutdown now
```

---

## Step 4: Generate Bootable ISO

### 4.1 Run ISO Creation Script

```bash
cd scripts
chmod +x create-iso-complete.sh
./create-iso-complete.sh
```

**What this does:**
- Creates initramfs with SquashFS and overlay filesystem support
- Compresses rootfs into SquashFS (saves space)
- Copies kernel and initramfs
- Creates GRUB bootloader configuration
- Builds final bootable ISO

**Expected output:**
```
✓ ISO CREATION SUCCESSFUL!
ISO Location: ~/myos/my-custom-linux.iso
ISO Size: ~2-3GB
```

### 4.2 Verify ISO

```bash
ls -lh ~/myos/my-custom-linux.iso
```

Should be under 4GB (typically 2-3GB with compression).

---

## Step 5: Test Your ISO

### Test in QEMU

```bash
qemu-system-x86_64 \
    -cdrom ~/myos/my-custom-linux.iso \
    -m 8G \
    -enable-kvm \
    -smp 4
```

### Test in virt-manager

1. Create new VM
2. Choose "Local install media"
3. Select your ISO
4. OS type: Arch Linux
5. RAM: 8GB, CPUs: 4
6. Start and test!

**Login:**
- Username: `ashu`
- Password: `ashu`

Hyprland should auto-start with your customizations!

---

## Troubleshooting

### Kernel Build Fails

**Problem:** Compilation errors during kernel build

**Solution:**
```bash
cd ~/kernel-rebuild/linux-6.12.60
make clean
make mrproper
cp ~/path/to/configs/kernel-config .config
make olddefconfig
make -j$(nproc)
```

### Rootfs Script Fails

**Problem:** `pacstrap` fails or packages not found

**Solution:**
```bash
# Update your host system first
sudo pacman -Syu

# Clear any partial rootfs
sudo umount /mnt/rootfs 2>/dev/null
rm -f ~/myos/rootfs.img

# Run script again
./rootfs-setup.sh
```

### VM Won't Boot

**Problem:** "Kernel panic" or "Failed to start"

**Solution:**
- Verify kernel path is absolute (not ~/)
- Check kernel args match: `root=/dev/vda rw`
- Ensure VirtIO disk is selected
- Check you have VirtIO drivers in kernel config

### ISO Too Large (>4GB)

**Problem:** ISO exceeds 4GB limit

**Solution:**
```bash
# Mount rootfs and clean more aggressively
sudo mount -o loop ~/myos/rootfs.img /mnt

# Remove locales (keep only English)
sudo find /mnt/usr/share/locale -mindepth 1 -maxdepth 1 -type d \
    ! -name 'en_US' ! -name 'en' -exec rm -rf {} +

# Remove documentation
sudo rm -rf /mnt/usr/share/doc/*
sudo rm -rf /mnt/usr/share/man/*

# Unmount and rebuild ISO
sudo umount /mnt
./create-iso-complete.sh
```

### Hyprland Won't Start

**Problem:** Black screen or crashes when running `Hyprland`

**Solution:**
```bash
# Check logs
journalctl -xe | grep hyprland

# Verify packages installed
pacman -Q | grep -E 'hyprland|wayland|waybar'

# Try rebuilding cache
sudo ldconfig
```

### Terminal Instantly Closes

**Problem:** Kitty terminal opens then immediately closes

**Solution:**
```bash
# Check kitty is installed
which kitty

# Try different terminal
pacman -S alacritty foot
```

---

## Customization Tips

### Change ISO Name

Edit `create-iso-complete.sh`:
```bash
ISO_NAME="my-awesome-distro.iso"
```

### Add More Packages

Edit `rootfs-setup.sh`, find the pacman install section and add packages:
```bash
pacman -S --noconfirm \
    hyprland \
    waybar \
    # Add your packages here
    firefox \
    thunderbird
```

### Include Your Dotfiles

After rootfs is created but before ISO:
```bash
sudo mount -o loop ~/myos/rootfs.img /mnt

# Copy your configs
sudo cp -r ~/.config/hypr /mnt/home/ashu/.config/
sudo cp -r ~/.config/waybar /mnt/home/ashu/.config/

# Fix permissions
sudo chown -R 1000:1000 /mnt/home/ashu/.config

sudo umount /mnt
```

### Change Default Wallpaper

Add wallpaper before ISO creation:
```bash
sudo mount -o loop ~/myos/rootfs.img /mnt
sudo cp ~/your-wallpaper.png /mnt/home/ashu/Pictures/wallpaper.png
sudo chown 1000:1000 /mnt/home/ashu/Pictures/wallpaper.png
sudo umount /mnt
```

---

## Build Time Estimates

| Step | Time |
|------|------|
| Kernel compilation | 30-60 min |
| Rootfs creation | 15-20 min |
| Hyprland customization | 10-30 min |
| ISO generation | 5-10 min |
| **Total** | **~1-2 hours** |

---

## Next Steps

After building your ISO:
1. Test thoroughly in VM
2. Document your customizations
3. Take screenshots
4. Create GitHub release
5. Share with the community!

---

## Additional Resources

- [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
- [Hyprland Documentation](https://wiki.hyprland.org/)
- [Kernel Compilation Guide](https://wiki.archlinux.org/title/Kernel/Traditional_compilation)
- [SquashFS Documentation](https://www.kernel.org/doc/Documentation/filesystems/squashfs.txt)

---

## Need Help?

If you encounter issues:
1. Check the troubleshooting section above
2. Open an issue on GitHub
3. Include logs and error messages
4. Mention which step failed

Happy building! 🚀
