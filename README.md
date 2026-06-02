# Arch Linux Minimalist Setup Guide

> ⚠️ **Warning**
> - This guide is for **advanced users** comfortable with the command line.
> - It assumes a **UEFI-only** system with a single NVMe/SSD drive.
> - **Data Loss Warning**: These steps will wipe the target drive. Backup your data first.
> - **Experimental**: While based on stable Arch practices, the specific combination of `systemd-homed`, UKIs, and TPM integration is experimental.

## Overview

This guide automates the installation of a highly optimized Arch Linux system tailored for laptops. It moves away from traditional `fstab` mounting and legacy bootloaders in favor of modern `systemd` features:

- **Unified Kernel Images (UKI)**: Kernels, initramfs, and cmdline bundled into a single EFI binary.
- **BTRFS Subvolumes**: Efficient snapshotting and separation of `/`, `/home`, `/var`, etc.
- **Secure Boot & TPM**: Full disk encryption unlocked automatically via TPM 2.0 with Secure Boot enforcement.

### The Workflow

The process is split into four distinct phases to ensure clarity and safety:

1.  **Prerequisites**: BIOS/UEFI configuration (Secure Boot Setup Mode, NVMe optimization).
2.  **Phase 1 (Pre-Chroot)**: Partitioning, LUKS encryption, BTRFS setup, and base system installation.
3.  **Phase 2 (Chroot)**: System configuration, UKI generation, and bootloader setup.
4.  **Phase 3 (Post-Reboot)**: User environment setup, AUR helper, services, and final Secure Boot/TPM enrollment.

---

## Prerequisites

Before starting the installation, perform these critical hardware and firmware configurations.

### 1. Enable Secure Boot Setup Mode
To sign kernels and initramfs later, your system must be in **Setup Mode**.
1.  Reboot and enter your UEFI/BIOS settings.
2.  Navigate to the **Secure Boot** section.
3.  **Clear all existing keys** (PK, KEK, db, dbx).
    *   *Note: This will put your system in "Setup Mode".*
4.  Save and exit.
5.  Verify in the live ISO shell:
    ```bash
    bootctl status
    ```
    Look for `Secure Boot: disabled (setup mode)`.

### 2. Optimize NVMe Logical Block Size
For optimal performance on modern NVMe drives, ensure the logical block size is set to **4096 bytes** (4K) if supported by your drive.
1.  Check current size:
    ```bash
    nvme id-ns -H /dev/nvme0n1 | grep "Relative Performance"
    ```
2.  This will then show us your optimal logical block sector size as recommended by your NVMe manufactuer. You should get an output such as this
    ```bash
    LBA Format  0 : Metadata Size: 0   bytes - Data Size: 512 bytes - Relative Performance: 0x2 Good (in use)
    LBA Format  1 : Metadata Size: 0   bytes - Data Size: 4096 bytes - Relative Performance: 0x1 Better
    ```
3.  This will format your drive, erasing all data on it. Please run it very carefully.
    ```bash
    nvme format --lbaf=[LBA Format number, typically 1] /dev/nvme0n1
    ```

### 3. Prepare the Live Environment
1.  Boot the latest Arch Linux ISO.
2.  Connect to the internet:
    ```bash
    iwctl station wlan0 connect "YOUR_SSID"
    # Or use ethernet
    ```
3.  Update the system clock:
    ```bash
    timedatectl set-ntp true
    ```
4.  Install `git` to clone this guide (or copy-paste the commands manually):
    ```bash
    pacman -Sy git
    ```

---

## Installation Steps

Proceed to the next file when ready:

1.  **[Step 1: Partitioning & Base Install](./STEP_1_PRE_CHROOT.md)**
    *   Partitioning (EFI, Swap, Root)
    *   LUKS Encryption
    *   BTRFS Subvolumes
    *   `pacstrap` base system

2.  **[Step 2: Chroot Configuration](./STEP_2_CHROOT.md)**
    *   Timezone & Locale
    *   UKI Generation (`mkinitcpio` + `systemd-boot`)
    *   `systemd-homed` User Creation
    *   Bootloader installation

3.  **[Step 3: Post-Reboot & Hardening](./STEP_3_POST_REBOOT.md)**
    *   Desktop Environment & Utilities
    *   AUR Helper (`paru`)
    *   Secure Boot Signing (`sbctl`)
    *   TPM 2.0 Enrollment (`systemd-cryptenroll`)

---

## License

This guide is provided **as-is** for personal use.
Feel free to fork and adapt, but there are **no guarantees of stability or support**.
