# Marty's Computer Setup [Arch]

# CURRENTLY UNTESTED US AT YOUR OWN RISK!
An arch linux installation script for my personal use. Works on my Frame.Work Laptop!

## What this sets up
+ UEFI - BIOS maybe done in the future...depending on how much work I want to do
+ BTRFS - subvolumes for `/home` `/var/cache/pacman/pkg` `/srv` `/var/log` `/tmp` `/.snapshots` `/swap`
+ SWAPFile - Mounts at `/swap/swafile`

Currently only installs intel-ucode for AMD systems change in `install.sh`

**`post_chroot` is not complete**

## Installation instructions after booting arch iso and connecting to network
1. `pacman -Sy git`
2. `git clone https://github.com/Marty1820/arch-install.git`
3. `cd arch-install`
4. edit `install.sh` & `post_chroot` files for you're needs
5. `chmod +x install.sh`
6. `./install.sh`
