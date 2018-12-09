# debian-live-build

Set up a custom debian live image (CD / USB) with the following features:

- Support for [ZFS](https://zfsonlinux.org)
- Enable SSH and root login on boot
	- Root password is `live`, remember to `passwd` ;)
- Auto boot (grub timeout=5)
- Set zsh as shell for root
- Install misc tools
- X (KDE)

Primarily for booting on EFI systems.

## Usage

Run on a Debian system.

```shell
# Install prerequisites.
apt-get update && apt-get install live-build

./build.sh
```

When the image is done, write it to a USB drive:

```shell
dd if=live-image-amd64.hybrid.iso of=/dev/sdX bs=4096 status=progress
```

## TODO

- Makefile
- Run in Docker

## Links

- [Live manual](https://live-team.pages.debian.net/live-manual/html/live-manual/index.en.html)
