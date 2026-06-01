# Step 3: Post-Reboot & Hardening

Welcome to your new Arch Linux system! This final phase completes the setup by installing your desktop environment and utilities, configuring the AUR helper, and performing the critical **Secure Boot** and **TPM 2.0** enrollment steps to unlock your disk automatically.

---

## 1. Install Packages

```bash
sudo pacman -Syu --needed --noconfirm 7zip awww base base-devel bat bc blueman brightnessctl btop cabextract dpkg efivar eza fastfetch fprintd framework-system fuzzel fwupd git gvfs intel-ucode jq kitty linux linux-firmware ly mako man-db man-pages neovim networkmanager niri nm-connection-editor npm nvme-cli playerctl python-requests rebuild-detector reflector rsync sbctl starship stow sudo swayidle swaylock syncthing thunar thunar-volman tldr tlp udisks2 ufw unace unrar unzip waybar wget wl-clipboard wlsunset xdg-utils zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting
```

---

## 2. Secure Boot & TPM Integration (Critical)

## A. Verify Setup Mode

Ensure your system is still in **Setup Mode** (keys cleared).
```bash
bootctl status
```

Look for `Secure Boot: disabled (setup mode).`

## B. Generate & Enroll Keys

```bash
# Create keys
sudo sbctl create-keys

# Enroll keys to firmware
sudo sbctl enroll-keys -m -f

# Verify what needs signing
sudo sbctl verify
```

## C. Sign Files

Sign every file listed by `sbctl verify`.
```bash
# Example: Sign the UKI and microcode
# Replace the paths with the actual output from 'sbctl verify'
sudo sbctl sign -s /boot/EFI/Linux/arch-linux.efi
sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
# Add more files if listed
```

- Repeat `sbctl verify` and `sbctl sign` until no unsigned files remain.

## D. Reboot & Enable Secure Boot

 1. Reboot your system.
 2. Enter UEFI/BIOS settings.
 3. Change **Secure Boot** from "Setup Mode" to "**Enabled**" (or "User Mode").
 4. Save and reboot.
 5. Verify
    ```bash
    bootctl status
    ```
    It should now say `Secure Boot: enabled (user)`.

## E. Enroll TPM 2.0 for Disk Unlock

Now that Secure Boot is active, we can bind the LUKS key to the TPM.

 1. **Generate a Recovery Key** (Save this somewhere safe!):
    ```bash
    # Replace /dev/nvme0n1p3 with your actual root partition
    sudo systemd-cryptenroll /dev/nvme0n1p3 --recovery-key
    ```
    Copy the generated recovery key string and store it offline (e.g., on a USB drive or paper).
 2. **Bind TPM**: (Change the drive to your encrypted partition)
    ```bash
    systemd-cryptenroll /dev/nvme0n1p3 --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+2+4+7:sha256
    ```
    Note: `0+2+4+7` measures BIOS, Boot Loader, and Kernel integrity. Adjust if needed.
 3. **Final Reboot**:
    ```bash
    reboot
    ```

---

## 3. Pacman & Makepkg Optimization

Optimize package manager and compilation settings.
```bash
# Enable colors and verbose lists
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf

# Set compiler flags for parallel builds
sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf
```

---

## 4. Install AUR Helper (paru)

We need `base-devel` and `git` to build the AUR helper `paru`.

```bash
# Install build tools
sudo pacman -Sy --needed --noconfirm base-devel git

# Clone and build paru
TEMP_DIR=$(mktemp -d)
git clone https://aur.archlinux.org/paru.git "$TEMP_DIR/paru"
cd "$TEMP_DIR/paru"
makepkg -si --noconfirm
cd /
rm -rf "$TEMP_DIR"

# Verify
paru --version
```

---

## 5. Configure Snapper (Snapshots)

Setup automatic snapshots for the root (`@root`) and home (`@home`) subvolumes.

```bash
# Root snapshot config
sudo snapper -c root create-config /

# Home snapshot config
sudo snapper -c home create-config /home

# Enable cleanup timers
sudo systemctl enable snapper-cleanup.timer
sudo systemctl enable snapper-backup.timer
sudo systemctl enable snapper-timeline.timer
```

---

## 6. Laptop Power Management

Configure `systemd` for suspend/hibernate behavior.

```bash
# Configure logind
sudo tee -a /etc/systemd/logind.conf > /dev/null <<EOF
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
HoldoffTimeoutSec=30s
EOF

# Configure sleep
sudo tee -a /etc/systemd/sleep.conf > /dev/null <<EOF
[Sleep]
HibernateDelaySec=1h
HibernateOnACPower=no
EOF

# Mask rfkill (required for TLP)
sudo systemctl mask systemd-rfkill.service
sudo systemctl mask systemd-rfkill.socket
```

---

## 7. Udev Rules

Create rules for low-battery hibernation, backlight permissions, and shared mounts.

```bash
# Low battery hibernation
sudo tee /etc/udev/rules.d/80-lowbat.rules > /dev/null <<EOF
SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="/usr/bin/systemctl hibernate"
EOF

# Backlight permissions
sudo tee /etc/udev/rules.d/90-backlight.rules > /dev/null <<EOF
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video \$sys\$devpath/brightness", RUN+="/bin/chmod g+w \$sys\$devpath/brightness"
EOF

# Shared mount points (for removable drives)
sudo tee /etc/udev/rules.d/99-udisks2.rules > /dev/null <<EOF
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

# Reload rules
sudo udevadm control --reload-rules
```

---

## 8. Enable System Services

Enable all necessary background services.

```bash
# Services
sudo systemctl enable ly@tty1.service
sudo systemctl enable NetworkManager.service
sudo systemctl enable bluetooth.service
sudo systemctl enable systemd-timesyncd.service
sudo systemctl enable udisks2.service
sudo systemctl enable fprintd.service
sudo systemctl enable tlp.service

# Timers
sudo systemctl enable fstrim.timer
sudo systemctl enable reflector.timer
sudo systemctl enable fwupd-refresh.timer
sudo systemctl enable paccache.timer

# Firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo systemctl enable ufw.service
```

---

## Success!

On the next boot, if Secure Boot is enabled and the system integrity is intact, the disk should unlock automatically without prompting for a password.
