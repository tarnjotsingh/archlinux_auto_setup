#!/bin/bash

# Default values, though some of these values will be overwritten anyway
MIN_DISK_SIZE=50000000
TARGET_INSTALL_DEVICE="sda"
FIRMWARE_TYPE=""
DISK_SIZE=""
BOOT_MOUNT=""
BOOT_DEV=""
LOCALE="en_GB"
TIME_ZONE="Europe/London"

# First check if the system this script being run on is EFI or BIOS.
if [ -d "/sys/firmware/efi" ]; then
	echo "UEFI system detected"
	FIRMWARE_TYPE="efi"
else
	echo "BIOS system detected"
	FIRMWARE_TYPE="bios"
fi


# The next part will be to partition the disk, I guess this could be scripted... 
# For now lets assume that the system has already been partitioned.

# Just check if the disk is big enough before we start, I'd like to see a minimum size of 50 gig
DISK_SIZE=$(cat /proc/partitions | awk -v target_dev=${TARGET_INSTALL_DEVICE} '$4 == target_dev {print $3}')

if [ ${DISK_SIZE} -gt ${MIN_DISK_SIZE} ]; then
	echo "Found disk /dev/${TARGET_INSTALL_DEVICE} of size ${DISK_SIZE}"
else
	echo "Disk /dev/${TARGET_INSTALL_DEVICE} of size ${DISK_SIZE} is not large enough."
	echo "Minimum disk size is currently set to ${MIN_DISK_SIZE}"
	exit 2
fi


# Check that a device has been mounted to /mnt/boot (/mnt/boot/efi on UEFI)
BOOT_MOUNT=$(mount | awk '$3 ~ "/mnt/boot" {print $3}')
BOOT_DEV=$(mount | awk '$3 ~ "/mnt/boot" {print $1}' | awk -F/ '{print $3}')

if [ ${BOOT_MOUNT} -ne "" ] && [ ${BOOT_DEV} == ${TARGET_INSTALL_DEVICE}* ]; then
	echo "/dev/${TARGET_INSTALL_DEVICE} partition has not been mounted to ${BOOT_MOUNT}"
	exit 3
else
	echo "BOOT_MOUNT=${BOOT_MOUNT}"
	echo "BOOT_DEV=${BOOT_DEV}"
fi

#.................................................Main arch installation.............................................


# Now that the partitiong stuff has been done...
# Check if we have a valid internet connection. Otherwise the installation cannot be carried out.
echo "Checking for internet connection..."
ping -c 1 http://www.google.com	

if [ $? -ne 0 ]; then
	echo "Failed to connect to the internet..."
	exit 1
fi

# If we have access to the internet, update the archlinux-keyring package if using an old ISO with old keyrings.
echo "Making sure archlinux-keyring is up to date..."
pacman -S archlinux-keyring
echo "Making sure package databases are up to date..."
pacman -Sy


# Now to carry out the main install for arch linux, installing both base and base-devel groups
pacstrap -i /mnt base base-devel
wait

# Generate file system table and store them to /etc/fstab
genfstab -U -p /mnt >> /mnt/etc/fstab

#Change root directory to /mnt (chroot)
arch-chroot /mnt

#...........................................NOW IN THE CHROOT..........................................................

# sed edit /etc/locale.gen going to be using the default value
sed -i.bak "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
export LANG=${LOCALE}.UTF-8
ln -sf /usr/share/zoneinfo/${TIME_ZONE}

# Set the HW Clock 
hwclock --systohc --utc

