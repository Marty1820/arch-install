#!/usr/bin/env bash
set -euo pipefail

read -rp "Hostname: " HOSTNAME
read -rp "Timezone (e.g., America/Chicago): " TIMEZONE
read -rsp "Root password: " ROOTPW; echo
read -rp "Username: " USERNAME
read -rsp "User password: " USERPW; echo

# Detect CPU vendor
CPU_VENDOR=$(lscpu | awk -F: '/Vendor ID:/ {print $2}' | xargs)
MICROCODE=""
[[ "$CPU_VENDOR" == "GenuineIntel" ]] && MICROCODE="/intel-ucode.img"
[[ "$CPU_VENDOR" == "AuthenticAMD" ]] && MICROCODE="/amd-ucode.img"

# Detect encrypted root partition
PART2=$(cryptsetup status root | awk '/device:/ {print $2}')
UUID_ROOT=$(blkid -s UUID -o value /dev/$PART2)

# Time
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
# Localization
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

# Network configuration
echo "$HOSTNAME" >/etc/hostname
cat >>/etc/hosts <<EOL
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
127.0.1.1       $HOSTNAME.localdomain $HOSTNAME
EOL
systemctl enable NetworkManager

# Initramfs
sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect kms block encrypt filesystems btrfs resume fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Root password
echo "root:$ROOTPW" | chpasswd

# systemd-boot
bootctl install

# Get resume_offset
OFFSET=$(btrfs inspect-internal map-swapfile -r /swap/swapfile)

# Kernel
KERNEL=${KERNEL:-linux}

cat >/boot/loader/entries/arch.conf <<EOL
title   Arch Linux ($KERNEL)
linux   /vmlinuz-$KERNEL
initrd  $MICROCODE
initrd  /initramfs-$KERNEL.img
options cryptdevice=UUID=$UUID_ROOT:root:allow-discards root=/dev/mapper/root rootflags=subvol=@root rw net.ifnames=0 quiet nvme.noacpi=1 mem_sleep_default=deep resume=/dev/mapper/root resume_offset=$OFFSET
EOL

# User creation
useradd -m -G wheel "$USERNAME"
echo "$USERNAME:$USERPW" | chpasswd
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Pacman + makepkg config
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf

echo "------------------------------------------------------"
echo "Arch installation complete. Reboot and remove media."
echo "------------------------------------------------------"
