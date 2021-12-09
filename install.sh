#!/bin/bash

echo "This script will install arch linux."
sleep 1

# Update the system clock
timedatectl set-ntp true
timedatectl status
sleep 1

# Partition the disks
read -p "Swap file size in G > " SWAP_SIZE
echo $SWAP_SIZE GB swap
fdisk -l
read -p "Type nvme0n1 > " DISK
echo "arch will be installed in $DISK"
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
  echo +512M # Last sector (Accept default: varies)
  echo t # Changing partition type
  echo 1 # Set type to EFI
  echo n # Add a new partition
  echo 2 # Partition number
  echo   # First sector (Accept default: 1)
   echo   # Last sector (Accept default: varies)
  echo w # Write changes
) | fdisk /dev/$DISK
  
  # Format the partitions
  echo "Formating partitions"
  #if ${DISK} == nvme0n1
  mkfs.fat -F32 /dev/${DISK}p1
  mkfs.btrfs /dev/${DISK}p2

  fdisk -l
  sleep 4
  
  # Create btrfs volumes
  echo "Creating btrfs volumes."
  mount /dev/${DISK}3 /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@var
  btrfs subvolume create /mnt/@opt
  btrfs subvolume create /mnt/@tmp
  btrfs subvolume create /mnt/@swap
  btrfs subvolume create /mnt/@.snapshots
  umount /mnt
  
  # Mount drives
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvolid=256,subvol=/@ /mnt
  cd /mnt
  mkdir -p {boot/efi,home,var,opt,tmp,swap,.snapshots}
  cd /
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@home /mnt/home
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@var /mnt/var
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@opt /mnt/opt
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@tmp /mnt/tmp
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@swap /mnt/swap
  mount -o rw,noatime,compress=zstd:3,ssd,space_cache,commit=120,subvol=/@.snapshots /mnt/.snapshots
  mount /dev/${DISK}p1 /mnt/boot/efi
  
  #Setting up SWAP
  ((SWAP=$SWAP_SIZE*1024))
  truncate -s 0 /mnt/swapfile
  chattr +C /mnt/swapfile
  btrfs property set /mnt/swapfile compression none
  dd if=/dev/zero of=/swap/swapfile bs=1M count=$SWAP
  chmod 600 /mnt/swapfile
  lsattr /mnt/swapfile
  mkswap /mnt/swapfile
  swapon /mnt/swapfile
  
  sleep 2
else
  echo "This script only work for UEFI mode"
  exit 0
fi

# Install essential packages
echo "Instaling essential packages."
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware networkmanager btrfs-progs git man-db man-pages texinfo sudo curl nano intel-ucode

# Generate an fstab file
echo "Generating fstab file."
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
sleep 1

# Change root into the new system:
echo "Change root into the new system."
echo -e "#!/bin/bash" >> install2.sh
echo -e "DISK=$DISK BOOT=$BOOT >> install2.sh
cat post_chroot >> install2.sh
cp install2.sh /mnt
chmod +x /mnt/install2.sh
arch-chroot /mnt ./install2.sh
