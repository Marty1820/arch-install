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

- **UEFI only**
- **BTRFS** with subvolumes for:
  - `/home`, `/srv`, `/var/log`, `/var/cache`, `/tmp`, `/.snapshots`

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
   nano 1.setup.sh
   ```
1. Make it executable and run:
   ```bash
   chmod +x 1.setup.sh
   ./1.setup.sh
   ```

## Next steps

After installation and configuration, login with user you created and run 3.finish.sh:

- AUR helper (paru)
- Extra services (TLP, Bluetooth, UFW, etc.)
- Udev rules (backlight, battery, shared mounts)
- System tweaks

For security follow 4.Secure.md

---

## License

This project is provided **as-is** for personal use.
Feel free to fork and adapt, but there are **no guarantees of stability or support**.
