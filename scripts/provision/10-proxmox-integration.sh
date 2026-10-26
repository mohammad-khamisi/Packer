#!/usr/bin/env bash
# Proxmox integration: qemu-guest-agent, cloud-init, serial console
set -euo pipefail

echo "==> [10-proxmox-integration]"

dnf -y install qemu-guest-agent cloud-init cloud-utils-growpart
# qemu-guest-agent is started by udev when the virtio port exists (Proxmox "QEMU Guest Agent" option)
systemctl enable qemu-guest-agent || true

# cloud-init: Proxmox provides a NoCloud (or ConfigDrive) drive
cat > /etc/cloud/cloud.cfg.d/99-proxmox.cfg <<'CFG'
datasource_list: [ NoCloud, ConfigDrive, None ]
# Grow root partition/filesystem when the disk is resized in Proxmox
growpart:
  mode: auto
  devices: ["/"]
resize_rootfs: true
# Keep Proxmox-provided hostname management
preserve_hostname: false
CFG

# Unit names differ between cloud-init versions; enable whichever exist
for unit in cloud-init-local cloud-init cloud-init-network cloud-config cloud-final; do
  systemctl list-unit-files "${unit}.service" >/dev/null 2>&1 && systemctl enable "${unit}.service" || true
done

# Serial console (Proxmox: Hardware -> Serial Port 0, Display -> serial0 optional)
systemctl enable serial-getty@ttyS0.service

echo "==> [10-proxmox-integration] done"
