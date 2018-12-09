#!/bin/bash
#
# Debian Live image creator
#
# Author: Mathias Fredriksson
# Based on: https://willhaley.com/blog/custom-debian-live-environment/
set -e

IN_CHROOT=0
if [[ $1 == chroot ]]; then
	IN_CHROOT=1
	shift
fi

SCRIPT="$0"
MIRROR="http://www.nic.funet.fi/debian/"
WORK=$(mktemp -d -t live-image.XXXX)
#WORK=/tmp/live-image.21Lr
CHROOT="$WORK/chroot"
mkdir -p "$WORK"

prepare() {
	apt-get -y install \
		debootstrap \
		squashfs-tools \
		xorriso \
		grub-pc-bin \
		grub-efi-amd64-bin \
		mtools

	debootstrap \
		--arch=amd64 \
		--variant=minbase \
		stretch \
		"$CHROOT" \
		$MIRROR
}

cont_in_chroot() {
	local name

	name="$(basename "$SCRIPT")"
	cp -a "$SCRIPT" "$CHROOT"

	mount --rbind /dev "$CHROOT"/dev
	mount --make-rslave "$CHROOT"/dev
	mount --rbind /proc "$CHROOT"/proc
	mount --make-rslave "$CHROOT"/proc
	mount --rbind /sys "$CHROOT"/sys
	mount --make-rslave "$CHROOT"/sys

	chroot "$CHROOT" /bin/bash ./"$name" chroot "$@"

	# Try to unmount a few times since this doesn't alway work on the first try...
	grep "$CHROOT" /proc/mounts | cut -f2 -d" " | sort -r | xargs umount -n || \
		grep "$CHROOT" /proc/mounts | cut -f2 -d" " | sort -r | xargs umount -n || \
		grep "$CHROOT" /proc/mounts | cut -f2 -d" " | sort -r | xargs umount -n

	rm "$CHROOT/$name"
}

chroot_prepare() {
	echo debian-live > /etc/hostname

	# Set root password to 'live'.
	echo $'live\nlive' | passwd root

	apt-get update
	apt-get -y install --no-install-recommends \
		linux-image-amd64 \
		live-boot \
		systemd-sysv
}

chroot_install_tools() {
	cat <<-EOS > /etc/apt/sources.list.d/contrib-non-free.list
	deb http://deb.debian.org/debian/ stretch contrib non-free
	EOS

	apt update
	apt-get -y install --no-install-recommends \
		grub-pc-bin \
		grub-efi-amd64-bin \
		sudo \
		curl \
		hdparm \
		sdparm \
		pciutils \
		usbutils \
		dnsutils \
		moreutils \
		net-tools \
		dosfstools \
		openssh-server \
		openssh-client \
		nano \
		vim \
		zsh \
		lsof \
		lshw \
		less \
		rsync \
		smartmontools \
		intel-microcode \
		cryptsetup \
		lvm2 \
		mdadm

	chsh -s /bin/zsh
}

chroot_install_zfs() {
	cat <<-EOS > /etc/apt/sources.list.d/zfs.list
	deb http://deb.debian.org/debian/ stretch-backports main contrib non-free
	EOS

	apt-get update
	apt-get -y install dpkg-dev linux-headers-amd64
	apt-get -y install -t stretch-backports zfs-dkms
}

chroot_finalize() {
	apt-get clean
}

finalize() {
	mkdir -p "$WORK"/{scratch,image/live}

	mksquashfs \
		"$CHROOT" \
		"$WORK"/image/live/filesystem.squashfs \
		-e boot

	cp "$CHROOT"/boot/vmlinuz-* "$CHROOT"/boot/initrd.img-* \
		"$WORK"/image/live

	cat <<EOF > "$WORK"/scratch/grub.cfg
insmod all_video
insmod play
play 960 440 1 0 4 440 1

if [ \${iso_path} ] ; then
  set loopback="findiso=\${iso_path}"
fi

search --set=root --file /DEBIAN_LIVE

set default="0"
set timeout=5

EOF

	(cd "$CHROOT"/boot || exit 1
		for kernel in vmlinuz-*; do
			version=${kernel#vmlinuz-}
			cat <<EOF >> "$WORK"/scratch/grub.cfg
menuentry "Debian GNU/Linux Live (kernel $version)" {
  linux  /live/vmlinuz-$version boot=live components "\${loopback}"
  initrd /live/initrd.img-$version
}
EOF
		done
	)

	# Create file used by grub to search for boot device.
	touch "$WORK"/image/DEBIAN_LIVE
}

create_iso() {
	grub-mkstandalone \
		--format=x86_64-efi \
		--output="$WORK"/scratch/bootx64.efi \
		--locales="" \
		--fonts="" \
		"boot/grub/grub.cfg=$WORK/scratch/grub.cfg"

	(cd "$WORK"/scratch
		dd if=/dev/zero of=efiboot.img bs=1M count=10
		mkfs.vfat efiboot.img
		mmd -i efiboot.img efi efi/boot
		mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
	)

	grub-mkstandalone \
		--format=i386-pc \
		--output="$WORK"/scratch/core.img \
		--install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
		--modules="linux normal iso9660 biosdisk search" \
		--locales="" \
		--fonts="" \
		"boot/grub/grub.cfg=$WORK/scratch/grub.cfg"

	cat /usr/lib/grub/i386-pc/cdboot.img "$WORK"/scratch/core.img \
		> "$WORK"/scratch/bios.img

	xorriso \
		-as mkisofs \
		-iso-level 3 \
		-full-iso9660-filenames \
		-volid "DEBIAN_LIVE" \
		-eltorito-boot boot/grub/bios.img \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		--eltorito-catalog boot/grub/boot.cat \
		--grub2-boot-info \
		--grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
		-eltorito-alt-boot \
		-e EFI/efiboot.img \
		-no-emul-boot \
		-append_partition 2 0xef "$WORK"/scratch/efiboot.img \
		-output "$WORK/debian-custom.iso" \
		-graft-points \
		"$WORK/image" \
		/boot/grub/bios.img="$WORK"/scratch/bios.img \
		/EFI/efiboot.img="$WORK"/scratch/efiboot.img
}

if (( IN_CHROOT )); then
	chroot_prepare
	chroot_install_tools
	chroot_install_zfs
	chroot_finalize
	exit 0
fi

prepare
cont_in_chroot "$@"
finalize
create_iso
