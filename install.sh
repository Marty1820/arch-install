#!/bin/bash

echo -ne "
----------------------------------------------------------------
  This script installs Arch on BTRFS with UEFI and swapfile
  YOUR DRIVE WILL BE FORMATED AND DELETE ALL DATA ON THE DISK
  Please make sure you know what you are doing because
  after formating your disk there is no way to get data back
----------------------------------------------------------------
"
read -p "Enter to continue <ctrl + c> to cancel"</dev/tty

# Update the system clock
timedatectl set-ntp true
timedatectl status
echo "Is the 'NTP service: active'?"
read -p "Enter to continue <ctrl + c> to cancel"</dev/tty

# Partition the disks
echo "Disk & Swap setup"
read -p "Enter swap file size in GBs > " SWAP_SIZE
echo ${SWAP_SIZE}GB swap
fdisk -l
read -p "Drive name (ex. sda or nvme0n1) > " DISK
echo "Arch will be installed on $DISK"
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
  echo +300M # Last sector (adds 512M space for EFI)
  echo t # Changing partition type
  echo 1 # Set type to EFI
  echo n # Add a new partition
  echo 2 # Partition number
  echo   # First sector (Accept default: varies)
  echo   # Last sector (Accept default: varies)
  echo w # Write changes
) | fdisk /dev/$DISK
  
  # NVME vs SSD/HDD
  echo "Formating partitions"
  if [[ "${DISK}" =~ "nvme" ]]; then
    parition=${DISK}p
  else
    partition=$DISK
  fi
  
  # Future encryption setup | UNTESTED!
  cryptsetup luksFormat /dev/${partition}2
  cryptsetup luksOpen /dev/${partition}2 root
  
  # Format partitions
  mkfs.vfat -F32 -n "EFI" /dev/${partition}1
  #mkfs.btrfs -L ROOT /dev/${partition}2
  mkfs.btrfs -L ROOT /dev/mapper/root

  fdisk -l
  echo "Do the partitions look ok?"
  read -p "Enter to continue <ctrl + c> to cancel"</dev/tty
  
  # Create btrfs volumes
  echo "Creating btrfs subvolumes."
  #mount /dev/${partition}2 /mnt
  mount /dev/mapper/root /mnt
  cd /mnt
  btrfs subvolume create @
  btrfs subvolume create @home
  btrfs subvolume create @srv
  btrfs subvolume create @log
  btrfs subvolume create @cache
  btrfs subvolume create @tmp
  btrfs subvolume create @snapshots
  btrfs subvolume create @swap
  ls /mnt
  echo ""
  echo "Are all subvolumes shown?"
  read -p "Enter to continue <ctrl + c> to cancel"</dev/tty
  umount /mnt

  # Mount / subvolume
  #mount -o relatime,compress=zstd,ssd,space_cache=v2,subvol=@ /dev/${partition}2 /mnt
  mount -o relatime,compress=zstd,ssd,space_cache=v2,subvol=@ /dev/mapper/crypt /mnt
  cd /mnt
  #Makes mount points
  mkdir -p {boot/efi,home,var/cache/pacman/pkg,svr,var/log,var/cache,tmp,.snapshots,swap}
  cd /
  mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@home /dev/mapper/root /mnt/home
  mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@srv /dev/mapper/root /mnt/srv
  mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@log /dev/mapper/root /mnt/var/log
  mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@cache /dev/mapper/root /mnt/var/cache
  mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@tmp /dev/mapper/root /mnt/tmp
  mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@snapshots /dev/mapper/root /mnt/.snapshots
  mount -o compress=no,ssd,space_cache=v2,discard=async,subvol=@swap /dev/mapper/root /mnt/swap
  mount /dev/${partition}1 /mnt/boot
  lsblk /dev/${DISK}
  echo "Are partitions/subvolumes mounted?"
  read -p "Enter to continue <ctrl + c> to cancel"</dev/tty
  
  #Setting up SWAP
  ((SWAP=$SWAP_SIZE*1024))
  truncate -s 0 /mnt/swap/swapfile
  chattr +C /mnt/swap/swapfile
  btrfs property set /mnt/swap/swapfile compression none
  dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=$SWAP status=progress
  chmod 600 /mnt/swap/swapfile
  mkswap /mnt/swap/swapfile
  swapon /mnt/swap/swapfile
  
  sleep 2
else
  echo "Boot mode BIOS"
  echo "Script not configured for BIOS...yet"
  exit 0
fi

# CPU information
proc=$(cat /proc/cpuinfo | grep vendor_id | awk 'NR==1 {print $3}')
if [[ $proc == GenuineIntel ]]; then
  ucode=intel-ucode
elif [[ $proc == AuthenticAMD ]]; then
  ucode=amd-ucode
else
  ucode=''
fi

# Kernel chooser
printf "linux\nlinux-hardened\nlinux-lts\nlinux-zen\n"
read -p "Please type in your kernel: " kern
read -p "Do you want headers installed(recommended)?(Y|n) " header
  case ${header:0:1} in
    Y|y ) 
    kern='$kern ${kern}-headers'
    ;;
    * )
    kern=$kern
    ;;
  esac


# Install essential packages
echo "Installing essential packages."
pacstrap /mnt base base-devel $ucode $kern linux-firmware \
  networkmanager btrfs-progs sudo nano

# Generate an fstab file
echo "Generating fstab file."
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
sleep 2

# Change root into the new system:
echo "Changing root into the new system."
echo -e "#!/bin/bash" >> install2.sh
echo -e "DISK=$DISK BOOT=$BOOT" >> install2.sh
cat post_chroot >> install2.sh
cp install2.sh /mnt/
chmod +x /mnt/install2.sh
arch-chroot /mnt ./install2.sh
