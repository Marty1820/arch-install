# Marty's Computer Setup [Arch]

# CURRENTLY UNTESTED US AT YOUR OWN RISK!
An arch linux installation script for my personal use. Works on my Frame.Work Laptop!

UEFI, BTRFS with subvolumes for root, home, opt, tmp, var, swap, & snapshots. 
Swapfile, intel system (can be switched in install.sh) on NVMe drive (if using SSD/HDD remove 'p' in install.sh


1. `pacman -Sy git`
2. `git clone https://github.com/Marty1820/arch-install.git`
3. `cd arch-install`
4. edit variables in install.sh & post_chroot files
5. `chmod +x install.sh`
6. `./install.sh`
