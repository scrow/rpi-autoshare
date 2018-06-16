#!/bin/bash

# This function from https://unix.stackexchange.com/a/28457
# Check if we are root and re-execute if we are not.
rootcheck () {
    if [ $(id -u) != "0" ]
    then
        sudo "$0" "$@"
        exit $?
    fi
}

rootcheck

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
	echo Sharing tun0...
	external_iface=$tun
elif [ -d /sys/class/net/$eth ]; then
	# iPhone exists, use it
	echo Sharing eth0...
	external_iface=$eth
elif [ -d /sys/class/net/$usb ]; then
	# Android exists, use it
	echo Sharing usb0...
	external_iface=$usb
else
	# Use wlan
	echo Sharing wlan0...
	external_iface=$wlan
fi

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

# Get external IP
external_ip=`ip addr show $external_iface | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`

if [ ! -z $external_ip ]; then
	# if $external_ip is not empty, then...
	# Make sure we can SSH out even if an OpenVPN session fires up
	route add 45.33.72.223 gw $external_ip metric 5 2> /dev/null
fi