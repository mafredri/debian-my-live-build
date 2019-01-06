#!/bin/bash
#
# This script builds custom debian live images, using live-build.
#
# Consult live-manual for more details:
# https://live-team.pages.debian.net/live-manual/html/live-manual/index.en.html

set -e

# For some reason, live build doesn't build anything other than `iso-hybrid`.
# Might use `hdd` here otherwise.
lb config \
	--distribution stretch \
	--binary-images iso-hybrid \
	"$@"

# Gimmeh X.
echo task-kde-desktop >config/package-lists/my-live.list.chroot

echo \
	cryptsetup \
	curl \
	dosfstools \
	less \
	lsb-release \
	lshw \
	lvm2 \
	mdadm \
	net-tools \
	openssh-client \
	openssh-server \
	pciutils \
	smartmontools \
	usbutils \
	vim \
	>config/package-lists/tools.list.chroot

# Link our pretty little hooks.
for hook in hooks/*/*; do
	(cd config/"$(dirname "$hook")" && ln -s ../../../"$hook" ./ || true)
done

# Let there be image.
lb build

# List devices, if lsscsi is available.
lsscsi 2>/dev/null || true

echo 'Time to "burn", make sure you use the right drive:'
echo "  dd if=live-image-amd64.img of=/dev/sdX bs=4096 status=progress"
