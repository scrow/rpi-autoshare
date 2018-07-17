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

To fully automate connection sharing, this script should be run from a cron job.  The script produces one file in `/tmp` which will need to be removed at boot to ensure the connection is set back up correctly.  Recommended crontab entries:

    @reboot    /path/to/rpi-autoshare/autoshare-reset.sh
    * * * * *  sleep 00; /path/to/rpi-autoshare/autoshare2.sh > /dev/null 2>&1
    * * * * *  sleep 15; /path/to/rpi-autoshare/autoshare2.sh > /dev/null 2>&1
    * * * * *  sleep 30; /path/to/rpi-autoshare/autoshare2.sh > /dev/null 2>&1
    * * * * *  sleep 45; /path/to/rpi-autoshare/autoshare2.sh > /dev/null 2>&1

## Customization

As of v2.1, an additional script can be called before and after setting up the sharing, when a change to the active interface is detected.  These files should be called `autoshare-prerun.sh` and `autoshare-postrun.sh`.  The postrun script is particularly helpful if you want/need to specify additional iptables rules, since the tables are completely flushed by this script when the interface changes.

Note that the `$internal_iface` and `$external_iface` variables are visible to the prerun/postrun scripts, should you wish to use those in those scripts for any additional interface configuration or iptables rules.

## Bug Reports

Bug reports can be submitted through the issue tracker on Github or via e-mail to the author at <mailto:scrow@sdf.org>.
