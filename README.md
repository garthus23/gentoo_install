# gentoo_install
script d'installation de gentoo desktop openrc 

this script install gentoo desktop with openrc on one disk with one partition EFI (500M), one partition BOOT(500M), one root encrypted (dm-crypt) partition (Space Left).
the root filesystem is btrfs with 3 subvolumes /var,/home,/etc
the desktop manager is i3 desktop with a Xorg server, google-chrome webbrowser (drm compatible,only binary, no endless compilation time), keepassxc password manager.
the hardware requirement is i5 or ryzen5, 8gb ram, 50gb disk

you should have a working internet connection before launching the installation script or it will fail.
don't forget to adapt the vars file to your environnement

## Download the gentoo live iso
https://distfiles.gentoo.org/releases/amd64/autobuilds/current-install-amd64-minimal/

## burn and boot on this iso
ex: dd if=~/Downloads/install-amd64-minimal-xxxxxx.iso of=/dev/yourusbpath

## set ip and dns 
the daemon dhcpcd should give you an ip
set the dns if no set : echo 'nameserver 8.8.8.8' > /etc/resolv.conf

## copy the script to liveiso root directory from usb or ssh
rc-service sshd start
passwd root 

### from client
scp install.sh vars root@192.168.1.x:~/

## Launch the script
./install.sh
