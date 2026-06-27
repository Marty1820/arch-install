# Step 3: Post-Reboot & Hardening

Welcome to your new Arch Linux system! This final phase completes the setup by installing your desktop environment and utilities, configuring the AUR helper, and performing the critical **Secure Boot** and **TPM 2.0** enrollment steps to unlock your disk automatically.

---

## 1. Install Packages

```bash
pacman -Syu --needed --noconfirm \
```

Followed by the list below

```text
nerd-fonts

7zip
awww
base
base-devel
bat
bc
blueman
brightnessctl
btop
btrfs-progs
cabextract
dosfstools
dpkg
efivar
exfat-utils
eza
fastfetch
fprintd
framework-system
fuzzel
fwupd
git
gtk4-layer-shell
gvfs
hypridle
hyprlock
intel-ucode
jq
kitty
linux
linux-firmware
ly
man-db
man-pages
neovim
networkmanager
niri
nm-connection-editor
npm
ntfsprogs
nvme-cli
pipewire-pulse
playerctl
python-requests
rebuild-detector
reflector
rsync
sbctl
sg3_utils
snapper
starship
stow
sudo
syncthing
thunar
thunar-volman
tldr
tlp
tlp-pd
udisks2
ufw
unace
unrar
unzip
upower
wget
wl-clipboard
wlsunset
xdg-utils
xfsprogs
zsh
zsh-autosuggestions
zsh-completions
zsh-syntax-highlighting
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
sbctl create-keys

# Enroll keys to firmware
sbctl enroll-keys -m -f

# Verify what needs signing
sbctl verify
```

## C. Sign Files

Sign every file listed by `sbctl verify`.
```bash
# Example: Sign the UKI and microcode
# Replace the paths with the actual output from 'sbctl verify'
sbctl sign -s /boot/EFI/Linux/arch-linux.efi
sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
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
    systemd-cryptenroll /dev/nvme0n1p3 --recovery-key
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
# Enable Hooks, Colors, and Verbose Package Lists
sed -i 's/^#HookDir/HookDir/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf

# Make Hooks directory
mkdir -p /etc/pacman.d/hooks

# Set compiler flags for parallel builds
sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf
```

---

## 4. Install AUR Helper (paru)

We need `base-devel` and `git` to build the AUR helper `paru`.

```bash
# Install build tools
pacman -Sy --needed --noconfirm base-devel git

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

Install Aur packages.

```bash
paru -Sy wayle-bin zen-browser-bin mpremote
```

---

## 5. Configure Snapper (Snapshots)

Setup automatic snapshots for the root (`@root`) and home (`@home`) subvolumes.

```bash
# Root snapshot config
snapper -c root create-config /

# Home snapshot config
snapper -c home create-config /home

# Enable cleanup timers
systemctl enable snapper-cleanup.timer
systemctl enable snapper-backup.timer
systemctl enable snapper-timeline.timer
```

---

## 6. Laptop Power Management

Configure `systemd` for suspend/hibernate behavior.

```bash
# Configure logind
tee -a /etc/systemd/logind.conf > /dev/null <<EOF
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
HoldoffTimeoutSec=30s
EOF

# Configure sleep
tee -a /etc/systemd/sleep.conf > /dev/null <<EOF
[Sleep]
HibernateDelaySec=1h
HibernateOnACPower=no
EOF

# Mask rfkill (required for TLP)
systemctl mask systemd-rfkill.service
systemctl mask systemd-rfkill.socket
```

---

## 7. Udev Rules

Create rules for low-battery hibernation, backlight permissions, and shared mounts.

```bash
tee /etc/udev/rules.d/60-lowbat.rules > /dev/null <<EOF
# Hibernate system when battery gets below 5%
# /etc/udev/rules.d/60-lowbat.rules
SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="/usr/bin/systemctl hibernate"
EOF

tee /etc/udev/rules.d/90-udisks2.rules > /dev/null <<EOF
# Shared mount points (for removable drives)
# /etc/udev/rules.d/90-udisks2.rules
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

tee /etc/udev/rules.d/99-backlight.rules > /dev/null <<EOF
# Enable video group to control backlight permissions
# /etc/udev/rules.d/99-backlight.rules
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF

tee /etc/udev/rules.d/99-mac-superdrive.rules > /dev/null <<EOF
# Apple SuperDrive initialization rule
# /etc/udev/rules.d/99-mac-superdrive.rules
# pacman -S sg3_utils
# See: https://gist.github.com/yookoala/818c1ff057e3d965980b7fd3bf8f77a6
ACTION=="add", ATTRS{idProduct}=="1500", ATTRS{idVendor}=="05ac", DRIVERS=="usb", RUN+="/usr/bin/sg_raw --cmdset=1 %r/sr%n EA 00 00 00 00 00 01"
EOF

# Reload rules
udevadm control --reload-rules
```

---

## 8. Enable System Services

Enable all necessary background services.

```bash
# Services
systemctl enable ly@tty1.service
systemctl enable NetworkManager.service
systemctl enable bluetooth.service
systemctl enable systemd-timesyncd.service
systemctl enable udisks2.service
systemctl enable fprintd.service
systemctl enable tlp.service
systemctl enable tlp-pd.service


# Timers
systemctl enable fstrim.timer
systemctl enable reflector.timer
systemctl enable fwupd-refresh.timer
systemctl enable paccache.timer

# Firewall
ufw default deny incoming
ufw default allow outgoing
systemctl enable ufw.service
```

---

## 9. User setup

Enable wheeel group sudo access

```bash
sed -i 's/^# %wheel/%wheel/' /etc/sudoers
```

Create a user using systemd-homed

```bash
# Start the service
systemctl enable systemd-homed.service

# Create a user with homectl
homectl create $USERNAME --shell=/usr/bin/zsh --member-of=wheel,video,uucp --storage=luks
```

After login verify user can run sudo then for security lock out root account

```bash
sudo passwd -l root
```

---

## Success!

On the next boot, if Secure Boot is enabled and the system integrity is intact, the disk should unlock automatically without prompting for a password. You can then log in with the user you created which will create the home directory.
