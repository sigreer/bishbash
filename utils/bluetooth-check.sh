#!/bin/bash

echo "lsusb:"
lsusb | grep -i bluetooth
echo ""
echo "lspci:"
lspci | grep -i bluetooth
echo ""
echo "dmesg:"
dmesg | grep -i bluetooth

bt_autosuspend=$(cat /sys/module/btusb/parameters/enable_autosuspend)
usb_autosuspend=$(cat /sys/module/usbcore/parameters/autosuspend)

echo "Bluetooth Autosuspend:	${bt_autosuspend}"
echo "USB Autosuspend: 		${usb_autospend}"

bt_firmware_version=$(dmesg | grep -i firmware | grep -i blue)
bt_firmware_version_available=$(rpm -q --info linux-firmware | grep -i version)

echo "Bluetooth FW version:	${bt_firmware_version}"
echo "Bluetooth FW available:	${bt_firmware_available}"
