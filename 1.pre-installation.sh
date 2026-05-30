#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo -e "\n----------------------------------------------------------------
  Arch Linux Installer (UEFI + LUKS + BTRFS + ext4 Home)
  WARNING: This will erase all data on the selected disk.
  Proceed only if you understand the consequences.
----------------------------------------------------------------"
read -rp "Enter to continue <ctrl + c> to cancel:" </dev/tty

# -----------------------
# Verify boot mode
# -----------------------
if [[ ! -d /sys/firmware/efi/efivars ]]; then
  echo "[ERROR] Not booted in UEFI mode. Exiting."
  exit 1
fi

# -----------------------
# User inputs
# -----------------------
fdisk -l
read -rp "Target disk (e.g., sda or nvme0n1): " DISK
[[ -b /dev/$DISK ]] || { echo "[ERROR] /dev/$DISK not found." exit 1; }

read -rp "Swap size in GB: " SWAP_SIZE
read -rp "Kernel (linux, linux-lts, linux-zen, linux-hardened): " KERNEL

read -rp "This will ERASE /dev/$DISK. Type 'yes' to confirm: " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { echo "Aborted."; exit 1; }

# -----------------------
# Partitioning
# -----------------------
echo "[INFO] Partitioning disk..."
parted -s /dev/"$DISK" mklabel gpt
parted -s /dev/"$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s /dev/"$DISK" set 1 esp on
parted -s /dev/"$DISK" mkpart root btrfs 1025MiB 51201MiB
parted -s /dev/"$DISK" mkpart home ext4 51201MiB 100%

# NVME vs SSD/HDD
if [[ "${DISK}" =~ "nvme" ]]; then
  EFI_PART=${DISK}p1
  ROOT_PART=${DISK}p2
  HOME_PART=${DISK}p3
else
  EFI_PART=${DISK}1
  ROOT_PART=${DISK}2
  HOME_PART=${DISK}3
fi

# -----------------------
# Encrypt root
# -----------------------
echo "[INFO] Setting up LUKS on $ROOT_PART"
cryptsetup luksFormat /dev/"$ROOT_PART"
cryptsetup open /dev/"$ROOT_PART" root

# -----------------------
# Format partitions
# -----------------------
mkfs.vfat -F32 -n "EFI" /dev/"$EFI_PART"
mkfs.btrfs -L ROOT /dev/mapper/root
mkfs.ext4 -L HOME /dev/$HOME_PART

# -----------------------
# Create BTRFS subvolumes
# -----------------------
mount /dev/mapper/root /mnt
subvols=( @root @srv @var_log @var_cache @tmp @snapshots @swap )
for sv in "${subvols[@]}"; do
  btrfs subvolume create /mnt/"$sv"
done
umount /mnt

# -----------------------
# Mount subvolumes
# -----------------------
MOUNT_OPTS="default,noatime,compress=zstd:1,ssd"
mount -o $MOUNT_OPTS,subvol=@root /dev/mapper/root /mnt
mkdir -p /mnt{boot/efi,srv,var/log,var/cache,tmp,.snapshots,swap,home}

declare -A MOUNT_MAP=(
  [@srv]=/mnt/srv
  [@var_log]=/mnt/var/log
  [@var_cache]=/mnt/var/cache
  [@tmp]=/mnt/tmp
  [@snapshots]=/mnt/.snapshots
  [@swap]=/mnt/swap
)
for sv in "${!mounts[@]}"; do
  mount -o $MOUNT_OPTS,subvol="$sv" /dev/mapper/root "${MOUNT_MAP[$sv]}"
done

mount /dev/"$EFI_PART" /mnt/boot/efi
mount /dev/"$HOME_PART" /mnt/home

# -----------------------
# Swapfile
# -----------------------
echo "[INFO] Creating swapfile..."
btrfs filesystem mkswapfile --size "${SWAP_SIZE}"G /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
swapon /mnt/swap/swapfile

# -----------------------
# CPU microcode
# -----------------------
UCODE=""
case "$(awk 'NR==1{print $3}' /proc/cpuinfo)" in
  GenuineIntel) UCODE=intel-ucode ;;
  AuthenticAMD) UCODE=amd-ucode ;;
esac

# -----------------------
# Install base system
# -----------------------
echo "[INFO] Installing essential packages..."
pacstrap /mnt base "$KERNEL" linux-firmware "$UCODE" \
  btrfs-progs networkmanager nvim man-db sbctl

# -----------------------
# Generate fstab
# -----------------------
genfstab -U /mnt >> /mnt/etc/fstab

# -----------------------
# Post-chroot setup
# -----------------------
echo -e "\n-----------------------------------------------------------
  Base system installed successfully.
  Next step: chroot into /mnt and run Part 2.
  Command: arch-chroot /mnt
-----------------------------------------------------------"
