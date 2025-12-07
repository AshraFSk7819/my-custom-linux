# Custom Linux Distribution - Arch-based with Hyprland

A lightweight, custom-built Linux distribution based on Arch Linux with a modern Hyprland desktop environment and custom kernel 6.12.60.

![Custom Linux](screenshots/desktop.png)

## 🎯 Project Overview

This project demonstrates building a complete Linux distribution from scratch, including:
- Custom compiled Linux kernel (6.12.60)
- Arch Linux base system
- Hyprland Wayland compositor
- Live ISO with overlay filesystem
- Optimized for virtual machines

## ✨ Features

- **Custom Kernel 6.12.60**
  - Compiled from source
  - Optimized for VM environments
  - SquashFS and Overlay filesystem support
  - Minimal bloat - only essential drivers

- **Modern Desktop Environment**
  - Hyprland (Wayland compositor)
  - Waybar status bar
  - Rofi launcher
  - Minimal and fast

- **Live ISO**
  - Boots from ISO without installation
  - Uses overlay filesystem (no lag)
  - Compressed with SquashFS
  - Under 4GB size

## 📋 System Requirements

**Minimum:**
- 4GB RAM
- 2 CPU cores
- VM with VirtIO support (QEMU/KVM)

**Recommended:**
- 8GB RAM
- 4 CPU cores

## 🚀 Quick Start

### Download ISO

Download the latest ISO from [Releases](../../releases) page.

### Boot in QEMU

```bash
qemu-system-x86_64 -cdrom my-custom-linux.iso -m 8G -enable-kvm -smp 4
```

### Login Credentials

- **Username:** ashu
- **Password:** ****(contactme)

## 🛠️ Build From Source

### Prerequisites

```bash
# Arch Linux host system
sudo pacman -S base-devel git wget curl
```

### Build Steps

1. **Clone this repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/my-custom-linux.git
   cd my-custom-linux
   ```

2. **Build the kernel**
   ```bash
   cd scripts
   chmod +x kernel-setup.sh
   ./kernel-setup.sh
   ```

3. **Create rootfs**
   ```bash
   chmod +x rootfs-setup.sh
   ./rootfs-setup.sh
   ```

4. **Build ISO**
   ```bash
   chmod +x create-iso-complete.sh
   ./create-iso-complete.sh
   ```

5. **Test the ISO**
   ```bash
   qemu-system-x86_64 -cdrom ~/myos/my-custom-linux.iso -m 8G -enable-kvm
   ```

## 📁 Project Structure

```
.
├── BUILD.md
├── configs/
│ ├── kernel-config
│ └── my-hyprland-configs/
│ ├──fastfetch/
│ ├── hypr/
│ ├── kitty/
│ ├── wallpaper/
│ └── waybar/
├── README.md
├── screenshots/
└── scripts/
├── create-iso-complete.sh
├── kernel-setup.sh
└── rootfs-setup.sh

```

## 🔧 Technical Details

### Kernel Configuration

- **Version:** 6.12.60
- **Config:** Minimal VM-optimized build
- **Key Features:**
  - VirtIO drivers (block, network, GPU)
  - SquashFS support
  - Overlay filesystem
  - Systemd requirements
  - EXT4 filesystem

### Initramfs

Custom initramfs with:
- BusyBox for utilities
- Overlay filesystem support
- Auto-detection of ISO device
- Minimal size (~750KB)

### Filesystem

- **Root:** SquashFS (compressed, read-only)
- **Overlay:** tmpfs (2GB, writable layer)
- **Result:** Fast boot, low RAM usage

## 🎨 Customization

### Change Desktop Theme

Edit Hyprland config in the rootfs:
```bash
sudo mount -o loop ~/myos/rootfs.img /mnt/rootfs
sudo nano /mnt/rootfs/home/ashu/.config/hypr/hyprland.conf
```

### Add/Remove Packages

Modify `rootfs-setup.sh` before building.

## 📊 Performance

- **Boot Time:** ~15-20 seconds
- **RAM Usage:** ~1.5GB idle
- **ISO Size:** ~2GB (compressed)
- **Rootfs Size:** ~3.5GB (uncompressed)

## 🐛 Known Issues

- "Failed to start Remount Root" warning on boot (harmless)
- Terminal occasionally closes on first launch (reopen works)
- Requires VM environment (not tested on real hardware)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📝 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- [Arch Linux](https://archlinux.org/) - Base system
- [Hyprland](https://hyprland.org/) - Wayland compositor
- [Linux Kernel](https://kernel.org/) - Kernel source

## 📧 Contact

Created by SK Ashraf Ahmed - feel free to contact me!

---

**Note:** This is an educational project demonstrating Linux system building. Not recommended for production us
