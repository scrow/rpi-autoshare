#!/bin/bash

# Forces a restart of the autoshare2.sh script

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

rm -f /tmp/share_iface.dat
./autoshare2.sh
