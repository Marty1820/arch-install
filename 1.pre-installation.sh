#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

echo -e "\n----------------------------------------------------------------
  This script installs Arch on BTRFS with UEFI and swapfile
  YOUR DRIVE WILL BE FORMATED AND DATA LOST
  Please make sure you know what you are doing because
  after formating your disk there is no way to get data back
----------------------------------------------------------------"
read -rp "Enter to continue <ctrl + c> to cancel:" </dev/tty

# Verify the boot mode
if [[ -d /sys/firmware/efi/efivars ]]; then
  echo "Boot mode UEFI"
else
  echo "Boot mode BIOS not supported. Exiting."
  exit 1
fi

# -----------------------
# User inputs
# -----------------------
fdisk -l
read -rp "Drive to install Arch on (e.g., sda or nvme0n1): " DISK
read -rp "Swap size in GB: " SWAP_SIZE
read -rp "Kernel (linux, linux-lts, linux-zen, linux-hardened): " KERNEL

# -----------------------
# Partitioning
# -----------------------
parted -s /dev/"$DISK" mklabel gpt
parted -s /dev/"$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s /dev/"$DISK" set 1 boot on
parted -s /dev/"$DISK" mkpart primary 1025MiB 100%

# NVME vs SSD/HDD
if [[ "${DISK}" =~ "nvme" ]]; then
  PART1=${DISK}p1
  PART2=${DISK}p2
else
  PART1=${DISK}1
  PART2=${DISK}2
fi

# -----------------------
# Encrypt root
# -----------------------
cryptsetup luksFormat /dev/"$PART2"
cryptsetup open /dev/"$PART2" root

# -----------------------
# Format partitions
# -----------------------
mkfs.vfat -F32 -n "EFI" /dev/"$PART1"
mkfs.btrfs -L ROOT /dev/mapper/root

# -----------------------
# Create BTRFS subvolumes
# -----------------------
mount /dev/mapper/root /mnt
subvols=( @root @boot @home @srv @log @cache @tmp @snapshots @swap )
for sv in "${subvols[@]}"; do
  btrfs subvolume create /mnt/"$sv"
done
umount /mnt

# -----------------------
# Mount subvolumes
# -----------------------
mount_opts="relatime,compress=zstd:3,ssd,space_cache=v2"
mount -o $mount_opts,subvol=@root /dev/mapper/root /mnt
mkdir -p {boot/EFI,var/cache/pacman/pkg,var/log,home,swap,.snapshots,srv,efi}

declare -A mounts=(
  [@boot]=/mnt/boot
  [@home]=/mnt/home
  [@srv]=/mnt/srv
  [@log]=/mnt/var/log
  [@cache]=/mnt/var/cache
  [@tmp]=/mnt/tmp
  [@snapshots]=/mnt/.snapshots
  [@swap]=/mnt/swap
)
for sv in "${!mounts[@]}"; do
  mount -o $mount_opts,subvol="$sv" /dev/mapper/root "${mounts[$sv]}"
done

mount /dev/"$PART1" /mnt/boot/EFI

# -----------------------
# Swapfile
# -----------------------
btrfs filesystem mkswapfile --size "${SWAP_SIZE}"G clear /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
swapon /mnt/swap/swapfile

# -----------------------
# Kernel and microcode
# -----------------------
CPU_VENDOR=$(awk 'NR==1{print $3}' /proc/cpuinfo)
[[ $CPU_VENDOR == "GenuineIntel" ]] && UCODE=intel-ucode
[[ $CPU_VENDOR == "AuthenticAMD" ]] && UCODE=amd-ucode
[[ -z ${UCODE-} ]] && UCODE=""

# -----------------------
# Install base system
# -----------------------
echo "Installing essential packages."
pacstrap /mnt base "$KERNEL" linux-firmware "$UCODE" btrfs-progs networkmanager nvim man-db sudo

# -----------------------
# Fstab
# -----------------------
genfstab -U /mnt >> /mnt/etc/fstab

# -----------------------
# Post-chroot setup
# -----------------------
echo -e "\n-----------------------------------------------------------
            Base system instalation completed. 
  To directly interact with the new system's environment
  change root into the new system with: `arch-chroot /mnt`
-----------------------------------------------------------"
