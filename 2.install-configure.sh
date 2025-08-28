#!/usr/bin/env bash
set -euo pipefail

read -rp "Hostname: " HOSTNAME
read -rp "Timezone (e.g., America/Chicago): " TIMEZONE
read -rsp "Root password: " ROOTPW; echo
read -rp "Username: " USERNAME
read -rsp "User password: " USERPW; echo

# Time
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
# Localization
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
locale-gen

# Network configuration
echo "$HOSTNAME" >/etc/hostname
cat >>/etc/hosts <<EOL
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
EOL

# Initramfs
sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode kms block encrypt filesystems btrfs resume fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Root password
echo -e "$ROOTPW\n$ROOTPW" | passwd

# systemd-boot
bootctl install
UUID_ROOT=\$(blkid -s UUID -o value /dev/\$PART2)
MICROCODE=""
[[ "$CPU_VENDOR" == "GenuineIntel" ]] && MICROCODE="/intel-ucode.img"
[[ "$CPU_VENDOR" == "AuthenticAMD" ]] && MICROCODE="/amd-ucode.img"

# Get resume_offset
OFFSET=$(btrfs inspect-internal map-swapfile -r /swap/swapfile)

cat > /boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux
initrd  \$MICROCODE
initrd  /initramfs-linux.img
options cryptdevice=UUID=\$UUID_ROOT:root:allow-discards root=/dev/mapper/root rootflags=subvol=@root rw net.ifnames=0 quiet nvme.noacpi=1 mem_sleep_default=deep resume=/dev/mapper/root resume_offset=\$OFFSET
EOL

# User creation
useradd -m -G wheel "$USERNAME"
echo -e "$USERPW\n$USERPW" | passwd "$USERNAME"
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Pacman config
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
# Makepkg config
sed -i 's/^#MAKEFLAGS=/MAKEFLAGS="j$(nproc)"' /etc/makepkg.conf

echo "Arch installation complete. Reboot and remove installation media."
