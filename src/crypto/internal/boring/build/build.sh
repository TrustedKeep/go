#!/bin/bash
# Copyright 2017 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Run on Ubuntu system set up with:
#	sudo apt-get install debootstrap
#	sudo apt-get install squid-deb-proxy
#	sudo /etc/init.d/squid-deb-proxy start
#
# The script sets up an Ubuntu chroot and then runs the build
# in that chroot, to make sure we know exactly what software
# is being used for the build. To repeat the script reusing the
# chroot installation, run build.sh -quick. This mode is useful
# if all you've modified is goboringcrypto.c and ../goboringcrypto.h
# (or some of the setup scripts in this directory).

# Comment this setting out if not using squid-deb-proxy,
# but it will be much slower to repeat the script.
http_proxy=http://127.0.0.1:8000

chroot=/var/tmp/boringssl

sudo umount -f $chroot/proc
sudo umount -f $chroot/sys
sudo umount -f $chroot/dev/pts
sudo umount -f $chroot/dev

set -e
if [ "$1" != "-quick" ]; then
	sudo rm -rf $chroot
	sudo http_proxy=$http_proxy debootstrap --variant=minbase bionic $chroot
fi

sudo chown $(whoami) $chroot
sudo chmod u+w $chroot

sudo mount -t proc proc $chroot/proc
sudo mount -t sysfs sys $chroot/sys
sudo mount -o bind /dev $chroot/dev
sudo mount -t devpts devpts $chroot/dev/pts

sudo cp sources.list $chroot/etc/apt/sources.list

cp *chroot.sh $chroot

cp /root/boringssl-ae223d6138807a13006342edfeef32e813246b39.tar.xz $chroot

rm -rf $chroot/godriver
mkdir $chroot/godriver
cp ../goboringcrypto.h $chroot/godriver

sudo http_proxy=$http_proxy chroot $chroot /root_setup_in_chroot.sh
sudo chroot --userspec=$(id -u):$(id -g) $chroot /build_in_chroot.sh
cp $chroot/godriver/goboringcrypto_linux_amd64.syso ..
sha256sum ../goboringcrypto_linux_amd64.syso
echo DONE
