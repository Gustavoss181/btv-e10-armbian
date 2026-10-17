#!/bin/sh
# Chamado pelos hooks em /etc/networkd-dispatcher/*/10-net-led
LED=/sys/class/leds/btv:status:net
if [ "$(cat /sys/class/net/eth0/carrier 2>/dev/null)" = "1" ] || \
   [ "$(cat /sys/class/net/wlan0/carrier 2>/dev/null)" = "1" ]; then
    echo 1 > "$LED/brightness"
else
    echo 0 > "$LED/brightness"
fi
