#!/usr/bin/env bash
# Extra network settings for Rocky Linux 10.2 (NetworkManager).
# The IP/gateway/DNS are already set by cloud-init; tune the rest here.
set -euo pipefail
echo "==> [20-network]"

# Main connection created by cloud-init (first active ethernet connection)
CON="$(nmcli -g NAME,TYPE connection show --active | awk -F: '$2=="802-3-ethernet"{print $1; exit}')"
echo "Active connection: ${CON:-none}"

# Examples - uncomment / edit as needed:
# nmcli connection modify "$CON" ethernet.mtu 9000
# nmcli connection modify "$CON" ipv6.method disabled
# nmcli connection modify "$CON" +ipv4.routes "10.0.0.0/8 192.168.10.254"
# nmcli connection up "$CON"

# Kernel network tuning
cat > /etc/sysctl.d/90-network.conf <<'CFG'
net.core.somaxconn = 4096
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 10240 65535
CFG
sysctl --system >/dev/null

echo "==> [20-network] done"
