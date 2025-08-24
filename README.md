![Status](https://img.shields.io/badge/status-experimental-orange)
![Arch Linux](https://img.shields.io/badge/Arch-Linux-blue)

> ⚠️ **Warning**
>
> - This project is **not updated frequently**
> - This project is **not fully tested**
> - **Use at your own risk**

# Arch Laptop Setup

An Arch Linux installation script for my personal use.  
This automates most of the base setup but assumes you know what you are doing.

---

## Features

- **UEFI only** (BIOS may be supported in the future)
- **BTRFS** with subvolumes for:
  - `/boot`, `/home`, `/srv`, `/var/log`, `/var/cache`, `/tmp`, `/.snapshots`, `/swap`
- **Swapfile** mounted at `/swap/swapfile`

---

## Installation

After booting the Arch ISO and connecting to the network:

1. Install Git:
   ```bash
   pacman -Sy git
   ```
1. Clone this repo:
   ```bash
    git clone https://github.com/Marty1820/arch-install.git
    cd arch-install
   ```
1. Edit the script to fit your needs:
   ```bash
   nano install.sh
   ```
1. Make it executable and run:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

## Next steps

After installation, see [`finishing_touches.md`](finishing_touches.md) for additional setup such as:

- AUR helper (paru)
- Extra services (TLP, Bluetooth, UFW, etc.)
- Udev rules (backlight, battery, shared mounts)
- System tweaks

---

## License

This project is provided **as-is** for personal use.  
Feel free to fork and adapt, but there are **no guarantees of stability or support**.
