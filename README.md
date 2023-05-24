| :exclamation: Not updated frequently |
| ------------------------------------ |

# Marty's Computer Setup [Arch]

# USE AT YOUR OWN RISK!

An arch linux installation script for my personal use. Works on my Frame.Work Laptop!

## What this sets up

- UEFI - BIOS maybe done in the future...depending on how much work I want to do
- BTRFS - subvolumes for `/home` `/srv` `/var/log` `/var/cache` `/tmp` `/.snapshots` `/swap`
- SWAPFile - Mounts at `/swap/swafile`

**`post_chroot` is not complete**

## Installation instructions after booting arch iso and connecting to network

1. `pacman -Sy git`
1. `git clone https://github.com/Marty1820/arch-install.git`
1. `cd arch-install`
1. edit `install.sh` & `post_chroot` files for you're needs
1. `chmod +x install.sh`
1. `./install.sh`
