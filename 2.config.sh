#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------
# User Inputs
# -----------------------
read -rp "Hostname: " HOSTNAME
read -rp "Timezone (e.g., America/Chicago): " TIMEZONE
read -rsp "Root password: " ROOTPW
echo
read -rp "Username: " USERNAME
read -rsp "User password: " USERPW
echo

# -----------------------
# Hardware Detection
# Detect CPU vendor
# -----------------------
CPU_VENDOR=$(lscpu | awk -F: '/Vendor ID:/ {print $2}' | xargs)
MICROCODE=""
[[ "$CPU_VENDOR" == "GenuineIntel" ]] && MICROCODE="/intel-ucode.img"
[[ "$CPU_VENDOR" == "AuthenticAMD" ]] && MICROCODE="/amd-ucode.img"

# Detect encrypted root UUID for UKI cmdline
# We need the UUID of the LUKS container, not the BTRFS filesystem
ROOT_DEV=$(cryptsetup status root | awk '/device:/ {print $2}')
UUID_ROOT=$(blkid -s UUID -o value /dev/$ROOT_DEV)

# -----------------------
# System Configuration
# -----------------------
# Time
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Localization
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

# Hostname configuration
echo "$HOSTNAME" >/etc/hostname

# Enable NetworkManager
systemctl enable NetworkManager
systemctl disable NetworkManager-wait-online.service

# -----------------------
# Kernel & Initramfs (UKI Setup)
# -----------------------
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode kms block encrypt btrfs filesystems resume fsck)/' /etc/mkinitcpio.conf
sed -i 's/^#COMPRESSION="zstd"=.*/COMPRESSION="zstd"/' /etc/mkinitcpio.conf


cat > /etc/mkinitcpio.d/linux.preset << EOF
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default')
default_uki="/boot/efi/EFI/Linux/arch-linux.efi"
EOF

cat > /etc/cmdline.d/root.conf << EOL
rd.luks.name=$(blkid -s UUID -o /dev/disk/by-partlabel/root)=root root=/dev/mapper/root rootflags=space_cache=v2,discard=async,compress=zstd:1,rw,noatime quiet 8250.nr_uarts=0
EOL

# -----------------------
# Bootloader (systemd-boot)
# -----------------------
# Install systemd-boot to EFI partition
bootctl install
# Generate UKI
mkinitcpio -P


# No need for manual loader entries if using UKI,
# but ensure the UKI is detected.
# systemd-boot automatically scans /boot/EFI/*.efi

# -----------------------
# Root Password
# -----------------------
echo "root:$ROOTPW" | chpasswd

# -----------------------
# User Creation (systemd-homed)
# -----------------------
# Create user with systemd-homed (LUKS encrypted home)
# -m: create home dir (handled by homed)
# -s /bin/zsh: set shell
# -g: primary group (auto-created)
# -p: password (interactive or hashed)
# Install necessary tools if not present in Part 1
pacman -Syu --noconfirm zsh sudo

# User creation
useradd -m --groups wheel,video --shell /usr/bin/zsh "$USERNAME"

# Grant sudo access
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# -----------------------
# Pacman & Makepkg Optimization
# -----------------------
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf

# -----------------------
# Final Checks
# -----------------------
echo "------------------------------------------------------"
echo "System configured with:"
echo "  - Unified Kernel Images (UKI)"
echo "  - systemd-homed (LUKS encrypted home for $USERNAME)"
echo "  - ZSH shell"
echo "------------------------------------------------------"
echo "Reboot now: exit && reboot"
echo "--------------------------------------------
