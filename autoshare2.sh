#!/bin/bash

# 
# scrow/rpi-autoshare
# Connection-sharing tool for the Raspberry Pi
# scrow@sdf.org
# 

PWD=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Check if we are root and re-execute if we are not.
# This function from https://unix.stackexchange.com/a/28457
rootcheck () {
    if [ $(id -u) != "0" ]
    then
        sudo "$0" "$@"
	cd "$PWD"
        exit $?
    fi
}

rootcheck

cd "$DIR"

# Read in the configuration file
if [ -f autoshare2.conf ]; then
	source autoshare2.conf
else
	echo "Configuration file autoshare2.conf not found."
	cd "$PWD"
	exit 1
fi

# Set up the forwarding, firewall, and routing tables
# Set up dnsmasq
/bin/systemctl stop dnsmasq
rm -f /etc/dnsmasq.d/custom-dnsmasq.conf > /dev/null 2>&1

if [ "$disable_internal_iface_gw" = true ]; then
	echo -e "interface=$internal_iface\n\
bind-interfaces\n\
server=8.8.8.8\n\
domain-needed\n\
bogus-priv\n\
dhcp-option=wireless-net,3\n\
dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time" > /etc/dnsmasq.d/custom-dnsmasq.conf
else
	echo -e "interface=$internal_iface\n\
bind-interfaces\n\
server=8.8.8.8\n\
domain-needed\n\
bogus-priv\n\
dhcp-option=wireless-net,3\n\
dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time" > /etc/dnsmasq.d/custom-dnsmasq.conf
fi

# Restart dnsmasq with the new configuration
/bin/systemctl start dnsmasq

# Flush iptables
/sbin/iptables -F
/sbin/iptables -t nat -F
/sbin/iptables -t mangle -F

for this_iface in "${external_iface_list[@]}"
do
	# Set up new iptables
	/sbin/iptables -t nat -A POSTROUTING -o "$this_iface" -j MASQUERADE
	/sbin/iptables -A FORWARD -i "$this_iface" -o "$internal_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT
	/sbin/iptables -A FORWARD -i "$internal_iface" -o "$this_iface" -j ACCEPT
done

# Enable v4 packet forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

cd "$PWD"
