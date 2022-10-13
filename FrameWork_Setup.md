# Marty's FrameWork Laptop Setup [Arch]

# Overview
+ UEFI
+ BTRFS - subvolumes for `/home`, `/srv`, `/var/log`, `/var/cache`, `/tmp`, `/.snapshots`, & `/swap`
+ SWAPFile - `/swap/swapfile` with hibernation

# Booted from Arch ISO
Connect to wifi:

    iwctl
    station wlan0 scan
    station wlan0 get-networks
    station wlan0 connect myssid
    
    ping archlinux.org

IMPORTANT: start NTP service

    timedatectl set-ntp true

Verify `NTP service` is active and sync hardware clock

    timedatctl status
    hwclock --systohc

## Disk Setup

Verify you are using UEFI

    ls /sys/firmware/efi/efivars

### Partitioning

See disks:

    lsblk

Partition disk:

    fdisk /dev/nvme0n1
    g # Creates a new empty GPT partition table

Make boot EFI partition:

    n
    1
    #ENTER for default first sector
    +300M
    t
    1

Make main linux partition:

    n
    2
    ENTER for default first sector
    ENTER for default last sector

Print parition table:

    p

Write the partiion table and exit:

    w

### Formating

Format the boot parition:

    mkfs.vfat -F32 -n "EFI" /dev/nvme0n1p1

Set up BTRFS on and encrypted LUKS partition:

     cryptsetup luksFormat /dev/nvme0n1p2
     YES
     passphrase
     cryptsetup luksOpen /dev/nvme0n1p2 root
     passphrase
     lsblk
     ls /dev/mapper
     mkfs.btrfs -L ROOT /dev/mapper/root
     mount /dev/mapper/root /mnt
     ls /mnt
 
 Set up BTRFS sub-volumes:
 
     btrfs subvolume create /mnt/@
     btrfs subvolume create /mnt/@home
     btrfs subvolume create /mnt/@srv
     btrfs subvolume create /mnt/@log
     btrfs subvolume create /mnt/@cache
     btrfs subvolume create /mnt/@tmp
     btrfs subvolume create /mnt/@snapshots
     btrfs subvolume create /mnt/@swap
     umount /mnt
 
 Mount the filesystems:

    mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@ /dev/mapper/root /mnt
    mkdir -p /mnt/{boot/efi,home,var/cache,srv,var/log,tmp,.snapshots,swap}
    mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@home /dev/mapper/cryptroot /mnt/home
    mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@srv /dev/mapper/root /mnt/srv
    mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@log /dev/mapper/root /mnt/var/log
    mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@cache /dev/mapper/root /mnt/var/cache
    mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@tmp /dev/mapper/root /mnt/tmp
    mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@snapshots /dev/mapper/root /mnt/.snapshots
    mount -o compress=no,ssd,discard=async,space_cache=v2,subvol=@swap /dev/mapper/root /mnt/swap
    mount /dev/nvme0n1p1 /mnt/boot
    lsblk /dev/nvme0n1

## SWAP setup

swap size is the `bs` multiplied by `count`, should be size of RAM plus a bit

    truncate -s 0 /mnt/swap/swapfile
    chattr +C /mnt/swap/swapfile
    btrfs property set /mnt/swap/swapfile compression none
    dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=20480 status=progress
    chmod 600 /mnt/swap/swapfile
    swapon /mnt/swap/swapfile

# Arch Installation

Pacstrap:

    pacstrap /mnt base base-devel intel-ucode linux-zen linux-firmware networkmanager btrfs-progs sudo nano

Generate fstab:

    genfstab -U /mnt >> /mnt/etc/fstab
  
Verify:

    cat /mnt/etc/fstab

Change root into new system:

    arch-chroot /mnt

Time/Localization setup:

    ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
    hwclock --systohc

Un-comment desired locales, e.g. en_US.UTF8 and en_US ISO-8859-1 in `/etc/locale.gen`

    nano /etc/locale.gen

Make locale.conf & generate locale's

    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    locale-gen

Hostname/Network:

    echo "HOSTNAME" > /etc/hostname
    nano /etc/hosts

Make /etc/hosts look like:

    # <ip-address>    <hostname.domain.org>   <hostname>
    127.0.0.1         localhost
    ::1		          localhost
    127.0.1.1	      HOSTNAME.localdomain	  HOSTNAME

Set root password/create user account:

    passwd
    useradd -m USERNAME
    paddwd USERNAME
    usermod -aG wheel video USERNAME
    passwd USERNAME
    EDITOR=nano visudo

Un-comment the line underneath "uncomment to allow members of group wheel to execute any command".

# Set up boot

    bootctl install
    touch /boot/loader/entries/arch-zen.conf

Get UUID of boot device and append it to end of file for cutting and pasting:

    blkid
    blkid | grep n1p2 | cut -d\" -f 2
    blkid | grep n1p2 | cut -d\" -f 2 >> /boot/loader/entries/arch-zen.conf # we need to edit this next
    nano /boot/loader/entries/arch-zen.conf

Make arch-zen.conf look like the below

    title Arch Linux Zen
    linux /vmlinuz-linux-zen
    initrd /intel-ucode.img
    initrd /initramfs-linux-zen.img
    options cryptdevice=UUID=PASTED-UUID:root:allow-discards root=/dev/mapper/root rootflags=subvol=@ rw net.ifnames=0 quiet nvme.noacpi=1 mem_sleep_default=deep

Enable systemd-boot-update

    systemctl enable systemd-boot-update.service

Set up boot image:

    nano /etc/mkinitcpio.conf

Edit the MODULES line to look like this:

    MODULES=(btrfs)

Edit the HOOKS line to look like this:

    HOOKS=(base udev autodetect modconf block encrypt btrfs filesystems keyboard fsck)

Then run:

    mkinitcpio -P
    
Enable services:

    systemctl enable paccache.timer
    systemctl enable NetworkManager.service
    systemctl enable systemd-resolved.service
    systemctl enable fstrim.timer
    systemctl enable snapper-timeline.timer
    systemctl enable snapper-cleanup.time

# Package Setup

Snapper

    snapper -c root create-config /
    snapper -c home create-config /home

edit `/etc/snapper/configs/*`

    # limits for timeline cleanup
    TIMELINE_MIN_AGE="1800"
    TIMELINE_LIMIT_HOURLY="5"
    TIMELINE_LIMIT_DAILY="7"
    TIMELINE_LIMIT_WEEKLY="1"
    TIMELINE_LIMIT_MONTHLY="0"
    TIMELINE_LIMIT_YEARLY="0"

FAIL2BAN

    pacman --needed --noconfirm -S fail2ban
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    touch /var/log/auth.log
    tee -a /etc/fail2ban/jail.local > /dev/null <<EOT
    [ssh]
    enabled = true
    port = ssh
    filter = sshd
    logpath = /var/log/auth.log
    maxretry = 6
    EOT

UFW

    pacman --needed --noconfirm -S ufw
    ufw default deny incoming
    ufw default allow outgoing
    systemctl enable ufw.service

Dunst notifications

    pacman --needed --noconfirm -S dunst libnotify
    touch /usr/share/dbus-1/services/org.freedesktop.Notifications.service
    tee /usr/share/dbus-1/services/org.freedesktop.Notifications.service > /dev/null <<EOT
    [D-BUS Service]
    Name=org.freedesktop.Notifications
    Exec=/usr/bin/dunst
    EOT

# Laptop Settings

Logind.conf settings

    sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=hibernate\\\nHandleLidSwitchExternalPower=suspend/' /etc/systemd/logind.conf
    sed -i 's/#HoldoffTimeoutSec=30s/HoldoffTimeoutSec=30s/' /etc/systemd/logind.conf

Low Battery Shutdown

    touch /etc/udev/rules.d/99-lowbat.rules
    tee -a /etc/udev/rules.d/99-lowbat.rules > /dev/null <<EOT
    # Suspend the system when battery level drops to 5% or lower
    SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="/usr/bin/systemctl hibernate"
    EOT

# Reboot

    exit
    swapoff /mnt/swap/swapfile
    umount -R /mnt
    reboot

Remove the USB stick. Type the LUKS password when prompted. Log in with your user created above.

# Connect to wifi upon login

    nmcli device wifi rescan
    nmcli device wifi list
    nmcli connection add WIFI_NAME
    nmcli connection up WIFI_NAME

# Install ALL the packages:

    sudo pacman --needed --noconfirm -Sy git pacman-contrib fwupd man-db man-pages texinfo systemd-resolvconf nm-connection-editor wireguard-tools tar libarchive binutils bzip2 gzip lzop xz zstd p7zip unrar zip unzip xarchiver curl tree exa bat wget exfat-utils bash-completion

Security, Battery, & Network

    sudo pacman --needed --noconfirm -Sy wireguard-tools tlp nm-connection-editor

Terminal & Shells

    sudo pacman --needed --noconfirm -Sy alacritty dash zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting wget btop checkbashisms exa fwupd man-db man-pages tldr nano nano-syntax-highlighting nvme-cli pacman-contrib reflector snapper starship tree

Drive Management

    sudo pacman --needed --noconfirm -Sy exfat-utils ntfs-3g android-tools rsync

Bluetooth & Audio

    sudo pacman --needed --noconfirm -Sy blueman bluez-utils alsa-utils pipewire wireplumber pipewire-pulse pipewire-alsa pamixer

WMs/Config Shortcuts

    sudo pacman --needed --noconfirm -Sy sway waybar grim slurp imv rofi dunst

File Manager

    sudo pacman --needed --noconfirm -Sy nemo nemo-fileroller gvfs-mtp xdg-user-dirs

Fonts

    sudo pacman --needed --noconfirm -Sy ttf-font-awesome ttf-hack powerline-fonts

MISC.

    pacman --needed --noconfirm -Sy galculator calibre gimp libreoffice-still vlc fprintd acpilight brightnessctl xf86-video-intel vulkan-intel

# Set up the AUR

Choose Rustup when given the choice.

    sudo pacman -S --needed base-devel
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si

Install AUR packages

    paru -S brave-bin minecraft-launcher nerd-fonts-complete ttf-ms-win11-auto vscodium-bin wev wlsunset a2ln

# Frame.Work Specific settings

acpi issue

    sed -i 's/#RebootWatchdogSec=0/RebootWatchdogSec=0/' /etc/systemd/system.conf

Stuttering and periodic freeze/No longer needed but doesn't cause issue's
    
    echo -e "options i915 enable_psr=0" >> /etc/modprobe.d/i915.conf

Fingerprint reader:

    sudo pacman -Sy fprintd
    fprintd-enroll

# Set up hibernation

Download this: https://github.com/osandov/osandov-linux/blob/master/scripts/btrfs_map_physical.c

    cd ~/Downloads
    gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
    sudo ./btrfs_map_physical /swap/swapfile
    sudo ./btrfs_map_physical /swap/swapfile | cut -f 9 | head -2
    getconf PAGESIZE
    
Divide the physical offset by the page size.

    blkid | grep root
    sudo nano /boot/loader/entries/arch-zen.conf
    
Add to `options` line:

    resume=/dev/mapper/root resume_offset=802233

Edit mkinitcpio

    sudo nano /etc/mkinitcpio.conf

Make `HOOKS` look like this (add resume after filesystems):

    HOOKS=(base udev autodetect modconf block encrypt btrfs filesystems resume keyboard fsck)
    
Now run:

     sudo mkinitcpio -P

Reboot once before trying to hibernate. Hibernate with:

    sudo systemctl hibernate