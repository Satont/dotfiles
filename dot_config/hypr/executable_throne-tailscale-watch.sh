#!/bin/bash
set -euo pipefail

TUN="throne-tun"
STATE="down"
LOGFILE="${HOME}/.local/share/throne-tailscale.log"

mkdir -p "$(dirname "$LOGFILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE" >&2
}

# Полный стоп tailscale: сначала корректно down, потом systemd
stop_tailscale() {
    if systemctl is-active --quiet tailscaled 2>/dev/null; then
        log "tailscale down..."
        sudo tailscale down 2>/dev/null || true
        sleep 1
        log "systemctl stop tailscaled"
        sudo systemctl stop tailscaled
    fi
}

# Полный старт: убеждаемся что мертв, ждем стабилизации tun, потом up
start_tailscale() {
    # Двойная страховка - tailscaled точно должен быть остановлен
    stop_tailscale
    
    # Ждем, пока Throne полностью пропишет маршруты в throne-tun
    # Если 7s мало - увеличь до 10-15
    log "Waiting 7s for throne-tun stabilization..."
    sleep 7
    
    log "systemctl start tailscaled"
    sudo systemctl start tailscaled
    sleep 2
    
    log "tailscale up..."
    sudo tailscale up --accept-routes 2>/dev/null || sudo tailscale up 2>/dev/null || true
    
    if tailscale status >/dev/null 2>&1; then
        log "Tailscale is UP"
    else
        log "WARNING: tailscale status check failed, may need manual toggle"
    fi
}

log "Watcher started"

while true; do
    if ip link show "$TUN" >/dev/null 2>&1; then
        if [ "$STATE" = "down" ]; then
            log "TUN appeared"
            start_tailscale
            STATE="up"
        fi
    else
        if [ "$STATE" = "up" ]; then
            log "TUN disappeared"
            stop_tailscale
            STATE="down"
        fi
    fi
    sleep 0.5
done
