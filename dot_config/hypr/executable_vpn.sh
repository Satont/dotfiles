#!/bin/bash
# Ждём, пока Throne поднимет TUN
/usr/bin/throne &

for i in {1..30}; do
    ip link show throne-tun >/dev/null 2>&1 && break
    sleep 1
done

# Теперь можно поднимать Tailscale
sudo systemctl start tailscaled

/etc/systemd/system/multi-user.target.wants/tailscaled.service
