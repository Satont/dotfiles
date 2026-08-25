#!/bin/bash
STATE="down"

while true; do
    if ip link show throne-tun >/dev/null 2>&1; then
        if [ "$STATE" = "down" ]; then
            sleep 3 
            systemctl restart tailscaled
            STATE="up"
        fi
    else
        STATE="down"
    fi
    sleep 1
done
