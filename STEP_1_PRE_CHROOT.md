# Step 1: Partitioning & Base Install

This phase prepares the disk, sets up encryption, creates the BTRFS filesystem with subvolumes, and installs the base Arch system.

> ⚠️ **WARNING**: This will **ERASE ALL DATA** on the target drive. Ensure you have backups before proceeding.

---

## 1. Verify UEFI Boot Mode

Ensure you're booted in UEFI mode (required for Secure Boot and UKIs).

```bash
ls /sys/firmware/efi/efivars
```

If you get an output you are running in UEFI, if not it's BIOS.

---

## 2. Identify Target Disk

List all disks to identify your target drive.

```bash
fdisk -l
```

Note the device name (e.g., `nvme0n1` or `sda`). Do not include the partition number.

---

## 3. Partition the disk

We will create three partitions:

| Partition | Size | Type | Purpose |
|:---|---|---|---:|
| 1 | 1GiB | EF00 (EFI) | Bootloader & UKIs |
| 3 | Rest | 8304 (Linux root(x86-64)) | Root filesystem |

### Execute Partitioning

Run gdisk /dev/*block-device* to open gdisk and prepare to partition the drives. Type the following keystrokes:

```bash
n
<Enter>
<Enter>
+1G
ef00
n
<Enter>
<Enter>
<Enter>
8304
w
```

---

## 4. Encrypt Root Partition

Set up LUKS2 encryption on the root partition

```bash
# Format with LUKS2 (enter passphrase twice)
cryptsetup luksFormat --type luks2 "/dev/$ROOT_PART"

# Open the encrypted volume
cryptsetup open "/dev/$ROOT_PART" root
```

* Remember your LUKS passphrase! You'll need it at boot.

---

## 5. Format Partitions

```bash
# EFI partition (FAT32)
mkfs.fat -F 32 -n "EFI" "/dev/$EFI_PART"

# Root partition (BTRFS)
mkfs.ext4 -L ROOT "/dev/mapper/root"
```

---

## 6. Mount Partitions

Mount all partitions with optimized options.

```bash
# Mount root partition
mount -o defaults,noatime /dev/mapper/root /mnt

# Mount EFI partition
mount -o fmask=0077,dmask=0077,nosuid,nodev,noexec --mkdir /dev/$EFI_PART /mnt/boot
```

---

## 7. Setup SWAP file

Create the swap file

```bash
mkswap -U clear --size 16g --file /mnt/swapfile
```

Activate the swap file

```bash
swapon /mnt/swapfile
```

---

## 9. Install Base System

Install the core packages needed for a functional system.

```bash
pacstrap -K /mnt base linux linux-firmware networkmanager neovim
```

---

## 10. Generate fstab

Create the filesystem table for the installed system.

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

---

## Phase 1 Complete

Your base system is installed. The next step is to chroot into the new system and configure it.

```bash
# Enter the new system
arch-chroot /mnt
```

> Continue to **[Step 2: Chroot Configuration](./STEP_2_CHROOT.md)**
