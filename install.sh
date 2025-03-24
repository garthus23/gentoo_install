#!/bin/bash

set -e

source ./vars

#### test Internet connection ###"
#ping -c 1 google.fr 


## umount disk if mounted
if [[ $(mount | grep /mnt/install) ]]
then
	umount -R /mnt/install
	cryptsetup close root
fi

wipefs -a /dev/${disk} 

# Define partitions: sda1: EFI , sda2: BOOT, sda3: ROOT

(
echo g # Create new gpt disk table
echo n # Primary partition creation
echo ''
echo ''
echo +500M # Partition number
echo t  # First sector (Accept default: 1)
echo 1  # Last sector (Accept default: varies)
echo n
echo ''
echo ''
echo +500M
echo t
echo 2
echo 142
echo n
echo ''
echo ''
echo ''
echo w # Write changes
) | fdisk /dev/$disk


# Encrypt The Root Partition

(
echo "$encrpass"
) | cryptsetup luksFormat --key-size 512 /dev/${disk}3

# Open And Mount The Newly encrypted partition

(
echo "$encrpass"
) | cryptsetup luksOpen /dev/${disk}3 root

mkfs.vfat -F32 /dev/${disk}1
mkfs.ext4 -F -L boot /dev/${disk}2
mkfs.btrfs -f -L rootfs /dev/mapper/root

if [[ ! -d /mnt/install ]]
then
	mkdir /mnt/install
fi
mount LABEL=rootfs /mnt/install
btrfs subvolume create /mnt/install/etc
btrfs subvolume create /mnt/install/home
btrfs subvolume create /mnt/install/var

# Mount ESP and BOOT on /

mkdir /mnt/install/efi
mount /dev/${disk}1 /mnt/install/efi
mkdir /mnt/install/boot
mount /dev/${disk}2 /mnt/install/boot

# Extracting Stage 3 archive in root directory
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/latest-stage3-amd64-desktop-openrc.txt --no-check-certificate
latest=$(grep -Eo 'stage3.*xz' latest-stage3-amd64-desktop-openrc.txt)
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/$latest --no-check-certificate
tar xpvf $latest --xattrs-include='*.*' --numeric-owner -C /mnt/install

# Set the compilation speed/parrallele jobs
echo "MAKEOPTS='$mkopts'" >> /mnt/install/etc/portage/make.conf
echo "nameserver $dnsserver" > /mnt/install/etc/resolv.conf

mount --types proc /proc /mnt/install/proc
mount --rbind /sys /mnt/install/sys
mount --make-rslave /mnt/install/sys
mount --rbind /dev /mnt/install/dev
mount --make-rslave /mnt/install/dev
mount --bind /run /mnt/install/run
mount --make-slave /mnt/install/run

cp vars /mnt/install

chroot /mnt/install /bin/bash <<"EOT"
set -e

source /etc/profile
source ./vars
export PS1="(chroot) ${PS1}"
echo 'GENTOO_MIRRORS="https://mirror.leaseweb.com/gentoo/ https://mirrors.evowise.com/gentoo/ https://mirrors.lug.mtu.edu/gentoo/ http://distfiles.gentoo.org"' >> /etc/portage/make.conf
emerge-webrsync

# List Profile 
#  eselect profile list

eselect profile set 23

emerge --ask=n --oneshot app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags
echo "*/* VIDEO_CARDS: amdgpu radeonsi" >  /etc/portage/package.use/00video_cards


echo "sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE" | tee -a /etc/portage/package.license
emerge --ask=n sys-kernel/linux-firmware
emerge --ask=n sys-firmware/sof-firmware
emerge --ask=n sys-kernel/installkernel
emerge --ask=n sys-kernel/ugrd
emerge --ask=n sys-fs/btrfs-progs
emerge --ask=n sys-fs/cryptsetup

echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
echo 'sys-kernel/installkernel grub' >> /etc/portage/package.use/installkernel

### AUTOMATIC KERNEL INSTALL

emerge --ask=n sys-kernel/installkernel grub


## MANUAL KERNEL INSTALL
#  emerge --ask=n sys-kernel/gentoo-sources
# ln -s /usr/src/$(ls /usr/src | grep linux-) /usr/src/linux
# cd /usr/src/linux
######### make localmodconfig or copy custom conf
# make && make modules_install
# make install

echo 'USE="X xinerama elogind alsa modules-sign secureboot ugrd"' >> /etc/portage/make.conf
emerge --ask=n sys-kernel/gentoo-kernel

#efibootmgr -c -d /dev/${disk} -p 1 -L "Gentoo" -l '\efi\boot\bootx64.efi' -u 'root=/dev/${disk}2 initrd=$(ls /boot | grep initramfs) quiet'

echo "/dev/${disk}2	/	btfrs	defaults	0 0" > /etc/fstab

grub-install --efi-directory=/efi

echo tux > /etc/hostname

useradd ${username}
echo "${username}:${pass}" | chpasswd
echo "root:${rootpass}" | chpasswd

#usermod -a -G wheel ${username}
usermod -a -G audio ${username}

emerge --ask=n app-admin/syslog-ng
rc-update add syslog-ng default

emerge --ask=n sys-process/lsof
emerge --ask=n sys-apps/pciutils
emerge --ask=n sys-process/cronie
rc-update add cronie default

emerge --ask=n app-shells/bash-completion

emerge --ask=n x11-base/xorg-server 
emerge --ask=n x11-terms/xterm
emerge --ask=n x11-apps/xinit
emerge --ask=n x11-apps/xrandr
emerge --ask=n x11-apps/setxkbmap
emerge --ask=n x11-misc/i3status
emerge --ask=n x11-misc/i3lock
emerge --ask=n x11-misc/dmenu


emerge --ask=n x11-wm/i3
emerge --ask=n app-editors/vim

echo '>=sys-libs/zlib-1.3.1-r1 minizip' > /etc/portage/package.use/keepassxc
emerge --ask=n app-admin/keepassxc

echo "www-client/google-chrome google-chrome" >> /etc/portage/package.license
emerge --ask=n www-client/google-chrome

emerge --ask=n x11-terms/qterminal

emerge --ask=n net-analyzer/iptraf-ng
emerge --ask=n net-analyzer/iftop
emerge --ask=n net-analyzer/tcpdump
emerge --ask=n net-analyzer/netcat

emerge --ask=n media-libs/alsa-lib
emerge --ask=n media-sound/alsa-utils
emerge --ask=n x11-misc/xvkbd

rc-update add elogind boot
rc-update add alsasound boot
emerge --ask=n net-dns/bind-tools
emerge --ask=n net-dns/unbound


cat > /etc/unbound/unbound.conf <<"EOF"
server:
        interface: ::1 
        port: 53
        prefer-ip6: yes
        outgoing-port-permit: 853
        do-ip4: no
        do-ip6: yes
        auto-trust-anchor-file: "/etc/unbound/var/dnssec-trust-anchors.key"
        do-udp: yes
        do-tcp: yes
        tcp-upstream: yes
        use-systemd: no
        access-control: ::1 allow
        tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"
python:

dynlib:

remote-control:
        control-enable: no

forward-zone:
        name: "."
        forward-tls-upstream: yes
        forward-first: no
        forward-no-cache: yes
        forward-addr: 2620:fe::9@853
EOF

cat > /etc/unbound/var/dnssec-trust-anchors.key <<"EOF"
.       3600    IN      DNSKEY  257 3 8 AwEAAaz/tAm8yTn4Mfeh5eyI96WSVexTBAvkMgJzkKTOiW1vkIbzxeF3+/4RgWOq7HrxRixHlFlExOLAJr5emLvN7SWXgnLh4+B5xQlNVz8Og8kvArMtNROxVQuCaSnIDdD5LKyWbRd2n9WGe2R8PzgCmr3EgVLrjyBxWezF0jLHwVN8efS3rCj/EWgvIWgb9tarpVUDK/b58Da+sqqls3eNbuv7pr+eoZG+SrDK6nWeL3c6H5Apxz7LjVc1uTIdsIXxuOLYA4/ilBmSVIzuDWfdRUfhHdY6+cn8HFRm+2hM8AnXGXws9555KrUB5qihylGa8subX2Nn6UwNR1AkUTV74bU= 
.       3600    IN      DNSKEY  257 3 8 AwEAAa96jeuknZlaeSrvyAJj6ZHv28hhOKkx3rLGXVaC6rXTsDc449/cidltpkyGwCJNnOAlFNKF2jBosZBU5eeHspaQWOmOElZsjICMQMC3aeHbGiShvZsx4wMYSjH8e7Vrhbu6irwCzVBApESjbUdpWWmEnhathWu1jo+siFUiRAAxm9qyJNg/wOZqqzL/dL/q8PkcRU5oUKEpUge71M3ej2/7CPqpdVwuMoTvoB+ZOT4YeGyxMvHmbrxlFzGOHOijtzN+u1TQNatX2XBuzZNQ1K+s2CXkPIZo7s6JgZyvaBevYtxPvYLw4z9mR7K2vaF18UYH9Z9GNUUeayffKC73PYc=
EOF

rc-update add unbound
echo 'nameserver ::1 > /etc/resolv.conf
echo 'nameserver ::1' > /etc/resolv.conf.head

EOT


