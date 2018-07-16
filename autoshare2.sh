#!/bin/bash

# Automatically shares available external network connection over specified $internal_iface
#
# To install packages needed for iOS and Android support:
# apt-get update; apt-get install gvfs ipheth-utils
# apt-get install libimobiledevice-utils gvfs-backends gvfs-bin gvfs-fuse
#
# To connect to an iOS device, enable the hotspot on the device before connecting to USB

# Define the interfaces
# Generally, the internal interface should be the name of your RPi's built-in ethernet port
# and other lines should be as-is.  However, if you want to run this script in reverse and
# share a wired Ethernet connection out of the built-in wireless interface, simply flip-flop
# the interface names between internal_interface and wlan below.
internal_iface="enxb827eb9a9898"
tun="tun0"
usb="usb0"
wlan="wlan0"
eth="eth0"

# Configure the DHCP server
internal_ip="192.168.253.1"
internal_netmask="255.255.255.0"
dhcp_range_start="192.168.253.2"
dhcp_range_end="192.168.253.253"
dhcp_time="12h"

# Check if we are root and re-execute if we are not.
# This function from https://unix.stackexchange.com/a/28457
rootcheck () {
    if [ $(id -u) != "0" ]
    then
        sudo "$0" "$@"
        exit $?
    fi
}

rootcheck

# Set up the forwarding, firewall, and routing tables
setup_sharing () {
	# Set up dnsmasq
	/bin/systemctl stop dnsmasq
	rm -rf /etc/dnsmasq.d/*

	# Enable ONE of the two following blocks of code.
	# The first one should be used if you're sharing out of the built-in Ethernet jack,
	# and prevents the system from using it as the default gateway (dhcp-option=wireless-net,3)
	# 
	# The second one shoudl be used in all other configurations (omits the dhcp-option line)
	echo -e "interface=$internal_iface\n\
bind-interfaces\n\
server=8.8.8.8\n\
domain-needed\n\
bogus-priv\n\
dhcp-option=wireless-net,3\n\
dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time" > /etc/dnsmasq.d/custom-dnsmasq.conf

#	echo -e "interface=$internal_iface\n\
#bind-interfaces\n\
#server=8.8.8.8\n\
#domain-needed\n\
#bogus-priv\n\
#dhcp-option=wireless-net,3\n\
#dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time" > /etc/dnsmasq.d/custom-dnsmasq.conf

	# Restart dnsmasq with the new configuration
	/bin/systemctl start dnsmasq

	# Flush iptables
	/sbin/iptables -F
	/sbin/iptables -t nat -F
	/sbin/iptables -t mangle -F

	# Set up new iptables
	/sbin/iptables -t nat -A POSTROUTING -o $external_iface -j MASQUERADE
	/sbin/iptables -A FORWARD -i $external_iface -o $internal_iface -m state --state RELATED,ESTABLISHED -j ACCEPT
	/sbin/iptables -A FORWARD -i $internal_iface -o $external_iface -j ACCEPT
}

# Enable v4 packet forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

if [ -d /sys/class/net/$tun ]; then
	# OpenVPN is up, so share that
	external_iface=$tun
elif [ -d /sys/class/net/$eth ]; then
	# iPhone exists, use it
	external_iface=$eth
elif [ -d /sys/class/net/$usb ]; then
	# Android exists, use it
	external_iface=$usb
else
	# Use wlan
	external_iface=$wlan
fi

# See which device was detected at last run
touch /tmp/share_iface.dat
current_external_iface=`cat /tmp/share_iface.dat`

if [ "$external_iface" == "$current_external_iface" ]; then
	# Device is unchanged, do nothing
	echo No change detected since last run.
else
	# Device has changed since last run

	echo Sharing $external_iface

	setup_sharing
fi

# Save external interface selection to disk
echo $external_iface > /tmp/share_iface.dat

