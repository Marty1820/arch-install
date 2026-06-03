# Step 2: Chroot Configuration

Now that the base system is installed, we enter the new environment to configure the system identity, generate Unified Kernel Images (UKIs), create the user with an encrypted home directory, and set up the bootloader.

> 💡 **Note**: Ensure you are inside the chroot environment.
> ```bash
> arch-chroot /mnt
> ```

---

## 1. System Identity & Localization

### Timezone
Set your timezone. Replace `America/Chicago` with your region.

```bash
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc
```

### Localization
Enable and generate the locale.

```bash
# Enable en_US.UTF-8
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

# Set default locale
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

### Hostname
Set your system hostname.

```bash
echo "HOSTNAME" > /etc/hostname
```

---

## 2. Network Configuration
Enable Network Manager to manage connections automatically.

```bash
systemctl enable NetworkManager
# Disable the wait-online service to speed up boot
systemctl disable NetworkManager-wait-online.service
```

---

## 3. Root Password

### Set Root Password
```bash
passwd
```

Type your password twice. We will lockout to root account later.

## 4. Unified Kernel Image (UKI) Setup

UKIs bunble the kernel, initramfs, microcode, and kernel command line into a single `.efi` file.

### Configure mkinitcpio
Update hooks to support UKI generation and encryption.
```bash
cat > /etc/mkinitcpio.conf <<EOF
MODULES=(btrfs)
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt btrfs filesystems resume fsck)
COMPRESSION="zstd"
EOF
```

### Configure UKI Preset
Tell `mkinitcpio` where to place the generated UKI.
```bash
cat > /etc/mkinitcpio.d/${KERNEL}.preset <<EOF
ALL_kver="/boot/vmlinuz-${KERNEL}"
PRESETS=('default')
default_uki="/boot/EFI/Linux/arch-${KERNEL}.efi"
EOF
```

### Configure Kernel Command Line
Create a dedicated cmdline file for the UKI.
```bash
UUID_ROOT=$(blkid -s UUID -o value /dev/mapper/root)

cat > /etc/cmdline.d/root.conf <<EOF
rd.luks.name=${UUID_ROOT}=root root=/dev/mapper/root rootflags=subvol=@root,space_cache=v2,discard=async,compress=zstd:1,rw,noatime quiet 8250.nr_uarts=0
EOF
```
### Generate UKI
Build the initramfs and the Unified Kernel Image.
```bash
mkinitcpio -P
```

## 5. Bootloader Installation

Install `systemd-boot` to the EFI partition. It will automatically detect the UKI we just created.
```bash
bootctl install
```

## 6. Final Checks

Verify the configuration before exiting.

```bash
# Check UKI
ls /boot/EFI/Linux/

# Check fstab
cat /etc/fstab
```

## Phase 2 Complete

Your system is configured with UKIs, and a functional bootloader.

```bash
# Exit chroot and reboot
exit
reboot
```

> Continue to **[Step 3: Post-Reboot & Hardening](./STEP_3_POST_REBOOT.md)**
