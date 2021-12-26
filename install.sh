#!/bin/bash

echo "This script will install arch linux with BTRFS on UEFI systems with a swapfile on an NVME drive."
sleep 3

# Update the system clock
timedatectl set-ntp true
timedatectl status
echo "Is the 'NTP service: active'?"
read -p "Enter to continue <ctrl + c> to cancel"</dev/tty

# Partition the disks
read -p "Swap file size in GBs > " SWAP_SIZE
echo $SWAP_SIZE GB swap
fdisk -l
read -p "Drive name (ex. nvme0n1) > " DISK
echo "arch will be installed on $DISK"
sleep 1

# Verify the boot mode
if [[ -d /sys/firmware/efi/efivars ]]; then
  echo "Boot mode UEFI"
  BOOT=uefi
  (
  echo g # Create a new empty GPT partition table
  echo n # Add a new partition
  echo 1 # Partition number
  echo   # First sector (Accept default: 1)
  echo +512M # Last sector (adds 512M space for EFI)
  echo t # Changing partition type
  echo 1 # Set type to EFI
  echo n # Add a new partition
  echo 2 # Partition number
  echo   # First sector (Accept default: varies)
  echo   # Last sector (Accept default: varies)
  echo w # Write changes
) | fdisk /dev/$DISK
  
  # Format the partitions
  echo "Formating partitions"
  #if ${DISK} == nvme0n1; then
  #  NVME == p
  mkfs.fat -F32 -L BOOT /dev/${DISK}p1
  mkfs.btrfs -L ROOT /dev/${DISK}p2

  fdisk -l
  echo "Do the partitions look ok?"
  read -p "Enter to continue <ctrl + c> to cancel"</dev/tty
  
  # Create btrfs volumes
  echo "Creating btrfs subvolumes."
  mount /dev/${DISK}p2 /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@log
  btrfs subvolume create /mnt/@tmp
  btrfs subvolume create /mnt/@swap
  btrfs subvolume create /mnt/@snapshots
  umount /mnt
  
  # Mount / subvolume
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvolid=256,subvol=/@ /mnt
  cd /mnt
  #Makes mount points
  mkdir -p {boot/efi,home,var/log,opt,tmp,swap,.snapshots}
  cd /
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@home /mnt/home
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@log /mnt/var/log
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@tmp /mnt/tmp
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@swap /mnt/swap
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@snapshots /mnt/.snapshots
  mount /dev/${DISK}p1 /mnt/boot/efi
  
  #Setting up SWAP
  ((SWAP=$SWAP_SIZE*1024))
  truncate -s 0 /mnt/swap/swapfile
  chattr +C /mnt/swap/swapfile
  btrfs property set /mnt/swap/swapfile compression none
  dd if=/dev/zero of=/swap/swapfile bs=1M count=$SWAP status=progress
  chmod 600 /mnt/swap/swapfile
  lsattr /mnt/swap/swapfile
  mkswap /mnt/swap/swapfile
  swapon /mnt/swap/swapfile
  
  sleep 2
else
  echo "Boot mode BIOS"
  echo "Script not configured for BIOS...yet"
  exit 0
fi

# Install essential packages
echo "Installing essential packages."
pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware NetworkManager intel-ucode btrfs-progs sudo

# Generate an fstab file
echo "Generating fstab file."
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
sleep 2

# Change root into the new system:
echo "Changing root into the new system."
echo -e "#!/bin/bash" >> install2.sh
echo -e "DISK=$DISK BOOT=$BOOT >> install2.sh
cat post_chroot >> install2.sh
cp install2.sh /mnt/
chmod +x /mnt/install2.sh
arch-chroot /mnt ./install2.sh
