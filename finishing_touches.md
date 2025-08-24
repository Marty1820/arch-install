# Finishing Touches after Base Arch Install

This document lists post-install steps, configurations, and service setups to finalize your Arch system.

---

## 1. Kernel & Initramfs Setup

- Edit `/etc/mkinitcpio.d/linux.preset` to include UKI paths:
  ```ini
  default_uki="/boot/EFI/EFI/Linux/arch-linux.efi"
  fallback_uki="/boot/EFI/EFI/Linux/arch-linux-fallback.efi"
  ```
- Create `/etc/cmdline.d/root.conf` with kernel parameters:
  ```text
  cryptdevice=UUID=<PART2_UUID>:root:allow-discards root=/dev/mapper/root rootflags=subvol=@root rw net.ifnames=0 quiet nvme.noacpi=1 mem_sleep_default=deep resume=/dev/mapper/root resume_offset=<OFFSET>
  ```

---

## 2. AUR Helper (paru)

- Install prerequisites
  ```bash
  sudo pacmand --needed -S base-devel
  ```
- Build and install **paru**:
  ```bash
  git clone https://aur.archlinux.org/paru.git
  cd paru
  makepkg -si
  cd .. && rm -dR paru
  ```
- Install AUR packages (example):
  ```bash
  paru -S waterfox-bin
  ```

---

## 3. Enable and Configure Services

- Power management:
  ```bash
  systemctl enable tlp.service
  systemctl mask systemd-rfkill.service
  systemctl mask systemd-rfkill.socket
  ```
- Networking & time sync:
  ```bash
  systemctl enable bluetooth.service
  systemctl enable systemd-timesyncd.service
  ```
- Misc.
  ```bash
  systemctl enable fwupd-refresh.timer
  systemctl enable fail2ban.service
  ```
- Enable firewall:
  ```bash
  sudo ufw enable
  ```

---

## 4. Laptop Configuration

Edit `/etc/systemd/logind.conf`:

- Set lid switch behavior:

  ```ini
  HandleLidSwitch=suspend-then-hibernate
  HandleLidSwitchExternalPower=suspend
  HandleLidSwitchDocked=ignore
  ```

- Reduce holdoff timeout:

  ```ini
  HoldoffTimeoutSec=30s
  ```

- Setup Hibernation in `/etc/systemd/sleep.conf`:

  ```ini
  HibernateDelaySec=5400 # 1.5hours
  HibernateOnACPower=no
  ```

---

## 5. Udev Rules

- **Shared mount points** (`/etc/udev/rules.d/99-udisks2.rules`):

  ```text
  ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
  ```

- **Low battery hibernation** (`/etc/udev/rules.d/99-lowbat.rules`):

  ```text
  SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="/usr/bin/systemctl hibernate"
  ```

- **Backlight permissions** (`/etc/udev/rules.d/backlight.rules`):

  ```text
  ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video $sys$devpath/brightness", RUN+="/bin/chmod g+w $sys$devpath/brightness"
  ```

---

## 6. ACPI Reboot Fix

Edit `/etc/systemd/system.conf`:

```ini
RebootWatchdogSec=0
```
