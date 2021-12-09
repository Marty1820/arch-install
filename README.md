# Marty's Computer Setup [Arch]
An arch linux installation script for my personal use. Works on my Frame.Work Laptop!

Setup for Intel processor if running AMD change ucode in post_chroot
Also if not on an NVME then need to remove the partition number in all the $DISK sections

BTRFS with swapfile on UEFI and Intel chipset

1. `pacman -Sy git`
2. `git clone https://github.com/Marty1820/arch-install.git`
3. `cd arch-install`
4. edit variables
5. `chmod +x install.sh`
6. `./install.sh`
