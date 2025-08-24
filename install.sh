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
read -rp "Hostname: " HOSTNAME
read -rp "Username: " USERNAME
read -rsp "User password: " USERPW; echo
read -rsp "Root password: " ROOTPW; echo
read -rp "Kernel (linux, linux-lts, linux-zen, linux-hardened): " KERNEL
read -rp "Timezone (e.g., America/Chicago): " TIMEZONE

# -----------------------
# Enable NTP
# -----------------------
timedatectl set-ntp true

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
mkdir -p {boot/EFI,var/cache/pacman/pkg,var/log,home,swap,.snapshots,srv}

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
pacstrap /mnt base "$UCODE" "$KERNEL" linux-firmware networkmanager btrfs-progs sudo

# -----------------------
# Fstab
# -----------------------
genfstab -U /mnt >> /mnt/etc/fstab

# -----------------------
# Post-chroot setup
# -----------------------
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# Hostname
echo "$HOSTNAME" >/etc/hostname
cat >>/etc/hosts <<EOL
127.0.0.1       localhost
::1             localhost
127.0.1.1       $HOSTNAME.localdomain $HOSTNAME
EOL

# Timezone & locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
locale-gen

# Root password
echo -e "$ROOTPW\n$ROOTPW" | passwd

# User creation
useradd -m -G wheel "$USERNAME"
echo -e "$USERPW\n$USERPW" | passwd "$USERNAME"
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Initramfs
sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode kms block encrypt filesystems btrfs resume fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Pacman config
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#CheckSpace/CheckSpace/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf

# Install extra packages
pacman --needed -Sy --noconfirm git pacman-contrib fwupd man-db man-pages nm-connection-editor wireguard-tools curl tree exa bat fail2ban ufw

# Enable services
systemctl enable NetworkManager.service
systemctl enable fstrim.timer
systemctl enable paccache.timer
systemctl enable fail2ban.service
ufw default deny incoming
ufw default allow outgoing
systemctl enable ufw.service

# systemd-boot
bootctl install
UUID_ROOT=\$(blkid -s UUID -o value /dev/\$PART2)
MICROCODE=""
[[ "$CPU_VENDOR" == "GenuineIntel" ]] && MICROCODE="/intel-ucode.img"
[[ "$CPU_VENDOR" == "AuthenticAMD" ]] && MICROCODE="/amd-ucode.img"

# Get `resume_offset`
OFFSET=$(btrfs inspect-internal map-swapfile -r /swap/swapfile)

cat > /boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux-zen
initrd  \$MICROCODE
initrd  /initramfs-linux-zen.img
options cryptdevice=UUID=\$UUID_ROOT:root:allow-discards root=/dev/mapper/root rootflags=subvol=@root rw net.ifnames=0 quiet nvme.noacpi=1 mem_sleep_default=deep resume=/dev/mapper/root resume_offset=\$OFFSET
EOL
systemctl enable systemd-boot-update.service
EOF

echo "Arch installation complete. Reboot and remove installation media."
