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
mkfs.fat -F32 -n "EFI" "/dev/$EFI_PART"

# Root partition (BTRFS)
mkfs.btrfs -L ROOT "/dev/mapper/root"
```

---

## 6. Create BTRFS Subvolumes

BTRFS subvolumes allow for efficient snapshots and separation of system directories.

```bash
# Mount root temporarily
mount /dev/mapper/root /mnt

# Create subvolumes
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@srv
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@swap

# Unmount root
umount /mnt
```

---

## 7. Mount Subvolumes

Mount all the subvolumes with optimized options.

```bash
# Mount root subvolume
mount -o defaults,noatime,commit=60,compress=zstd,subvol=@root /dev/mapper/root /mnt

# Mount other subvolumes
mount -o defaults,noatime,commit=60,compress=zstd,subvol=@srv --mkdir /dev/mapper/root /mnt/srv
mount -o defaults,noatime,commit=60,compress=zstd,subvol=@var_log --mkdir /dev/mapper/root /mnt/var/log
mount -o defaults,noatime,commit=60,compress=zstd,subvol=@var_cache --mkdir /dev/mapper/root /mnt/var/cache
mount -o defaults,noatime,commit=60,compress=zstd,subvol=@tmp --mkdir /dev/mapper/root /mnt/tmp
mount -o defaults,noatime,commit=60,compress=zstd,subvol=@snapshots --mkdir /dev/mapper/root /mnt/.snapshots
mount -o defaults,noatime,commit=60,compress=zstd,subvol=@home --mkdir /dev/mapper/root /mnt/home
mount -o subvol=@swap --mkdir /dev/mapper/root /mnt/swap

# Mount EFI partition
mount -o fmask=0077,dmask=0077,nosuid,nodev,noexec /dev/$EFI_PART /boot
```

---

## 8. Setup SWAP file

Create the swap file

```bash
btrfs filesystem mkswapfile --size 16g /swap/swapfile
```

Activate the swap file

```bash
swapon /mnt/swap/swapfile
```

---

## 9. Install Base System

Install the core packages needed for a functional system.

```bash
pacstrap -K /mnt base linux linux-firmware btrfs-progs networkmanager neovim sbctl
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
