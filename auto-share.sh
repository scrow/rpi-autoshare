#!/bin/bash

# Automatically shares available external network connection over specified $internal_iface
#
# To install packages needed for iOS and Android support:
# apt-get update; apt-get install gvfs ipheth-utils
# apt-get install libimobiledevice-utils gvfs-backends gvfs-bin gvfs-fuse
#
# To connect to an iOS device, enable the hotspot on the device before connecting to USB

# Check if we are root and re-execute if we are not.
# This function from https://unix.stackexchange.com/a/28457
rootcheck () {
    if [ $(id -u) != "0" ]
    then
        sudo "$0" "$@"
        exit $?
    fi
}

setup_default_route () {
	# Get external IP
	external_ip=`ip addr show $external_iface | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`

	if [ ! -z $external_ip ]; then
		# if $external_ip is not empty, then...
		# Make sure we can SSH out even if an OpenVPN session fires up
		route add 45.33.72.223 gw $external_ip metric 5 2> /dev/null
	fi

	# Save external IP to disk
	echo $external_ip > /tmp/share_ip.dat
}

# Set up the forwarding, firewall, and routing tables
setup_sharing () {
	# Delete output device default route
	/sbin/ip route del 0/0 dev $internal_iface 2> /dev/null
	/sbin/ip route del default dev $internal_iface 2> /dev/null

	# Set up dnsmasq
	/bin/systemctl stop dnsmasq
	rm -rf /etc/dnsmasq.d/*
	echo -e "interface=$internal_iface\n\
bind-interfaces\n\
server=8.8.8.8\n\
domain-needed\n\
bogus-priv\n\
dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time" > /etc/dnsmasq.d/custom-dnsmasq.conf
/bin/systemctl start dnsmasq

	# Flush iptables
	/sbin/iptables -F
	/sbin/iptables -t nat -F
	/sbin/iptables -t mangle -F

	# Set up new iptables
	/sbin/iptables -t nat -A POSTROUTING -o $external_iface -j MASQUERADE
	/sbin/iptables -A FORWARD -i $external_iface -o $internal_iface -m state --state RELATED,ESTABLISHED -j ACCEPT
	/sbin/iptables -A FORWARD -i $internal_iface -o $external_iface -j ACCEPT

	setup_default_route
}

rootcheck

# Configure these to reflect your device names.  The default configuration is to
# forward traffic from a wireless or USB device to the wired network port, identified
# as $internal_interface.  If you want to go the other way, and share a wired or USB
# device out of a `hostapd` wireless hotspot on wlan0, just flip-flop the internal
# and wlan interfaces here.
internal_iface="enxb827eb9a9898"
tun="tun0"
usb="usb0"
wlan="wlan0"
eth="eth0"

internal_ip="192.168.253.1"
internal_netmask="255.255.255.0"
dhcp_range_start="192.168.253.2"
dhcp_range_end="192.168.253.253"
dhcp_time="12h"

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

# See if external IP has changed since last run, and if so, re-do the default route
# This should help allevate lengthy connection stalls or lockups if the external
# interface IP address changes.  I think this will also address some captive portal
# issues when sharing a public hotspot connection (hotel WiFi, etc) but need to test.
# Get external IP
external_ip=`ip addr show $external_iface | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`
if [ "$external_ip" == "`cat /tmp/share_ip.dat`" ]; then
	setup_default_route
fi