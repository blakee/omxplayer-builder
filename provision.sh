#!/bin/bash

set -e
#set -x

apt-get -y install kpartx git dosfstools qemu-kvm-extras-static binfmt-support ia32-libs

if ! [ -d /home/vagrant/tools ]; then
	git clone git://github.com/raspberrypi/tools.git /home/vagrant/tools
	cd /home/vagrant/tools; git checkout HEAD~1 # temp fix for a broken compiler in repo
fi

rm -rf /home/vagrant/omxplayer

#git clone https://github.com/popcornmix/omxplayer.git /home/vagrant/omxplayer
git clone https://github.com/blakee/omxplayer.git /home/vagrant/omxplayer

image=/vagrant/pi.img
if ! [ -f "$image" ]; then
	echo "missing $image" >&2
	exit 2
fi
device=`kpartx -va ${image} | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
device="/dev/mapper/${device}"
bootp=${device}p1
rootp=${device}p2
mkdir -p /opt/bcm-rootfs
mount "$rootp" /opt/bcm-rootfs
mount "$bootp" /opt/bcm-rootfs/boot

cd /home/vagrant/omxplayer

sed -i 's/ -j9//g;s!/home/dc4/!/home/vagrant/!g;s!^INCLUDES.*$!INCLUDES\t\t+= -isystem$(SDKSTAGE)/opt/vc/include -isystem$(SYSROOT)/usr/include -isystem$(SDKSTAGE)/opt/vc/include/interface/vcos/pthreads -isystem$(SDKSTAGE)/opt/vc/include/interface/vmcs_host/linux -isystem$(SDKSTAGE)/usr/lib/arm-linux-gnueabihf/dbus-1.0/include -isystem$(SDKSTAGE)/usr/include/dbus-1.0 -isystem$(SDKSTAGE)/usr/include/freetype2 -Ipcre/build -Iboost-trunk!' Makefile.*
export PATH=$PATH:/home/vagrant/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin
make ffmpeg
make
make dist

until umount ${bootp}; do sleep 1; done
until umount ${rootp}; do sleep 1; done

until dmsetup remove ${bootp}; do sleep 1; done
until dmsetup remove ${rootp}; do sleep 1; done

until kpartx -d ${image}; do sleep 1; done

mkdir -p /vagrant/out
cp /home/vagrant/omxplayer/omxplayer-dist.tgz /vagrant/out

echo "tarball generated, check 'out' directory"

