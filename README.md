# scrow/rpi-autoshare

This tool automatically shares an available external network connection over the specified interface.  It is intended to automatically share a Wi-Fi connection, or a tethered iPhone or Android hotspot connection, over the wired Ethernet jack on a Raspberry Pi.  It's written specifically for the RPi 3, but may work on other models.

This script also supports sharing of an OpenVPN tunnel, which would route all traffic coming in from the wired Ethernet jack across the tunnel, securing the traffic.  (Creation of the OpenVPN tunnel is outside the scope of this document.)

## Prerequisites

To share an iPhone device, you'll need to install a few packages.  Assuming Raspbian Stretch:

    sudo apt-get update
    sudo apt-get install gvfs ipheth-utils
    sudo apt-get install libimobiledevice-utils gvfs-backends gvfs-bin gvfs-fuse

To connect to an iOS device, enable the hotspot on the device before connecting to USB.  When asked if you trust the computer, select "yes."

## Installation

To install, download or clone this repository to any location on your system which is accessible at boot.  Copy the `autoshare2.conf.example` file to `autoshare2.conf` and edit the configuration file.  Configuration instructions are inside the file.

## Execution

As of v2.1, forwarding is configured across all interfaces defined in the `external_iface_list` variable inside `autoshare2.conf`.  There is no longer any need to repeatedly call this script, and it no longer checks to see which interfaces are active.  A one-shot execution at bootup should be sufficient.  In crontab:

    @reboot    /path/to/rpi-autoshare/autoshare2.sh

## Bug Reports

Bug reports can be submitted through the issue tracker on Github or via e-mail to the author at <mailto:scrow@sdf.org>.
