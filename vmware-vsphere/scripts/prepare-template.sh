#!/usr/bin/env bash
# Prepare a Rocky Linux 10.2 VM to be used as the vSphere template.
# Run ONCE as root inside the VM, then power it off and convert it to a template:
#   sudo bash prepare-template.sh && sudo poweroff
set -euo pipefail

echo "==> Checking OS"
. /etc/os-release
if [[ "${ID}" != "rocky" || "${VERSION_ID%%.*}" != "10" ]]; then
  echo "WARNING: expected Rocky Linux 10.x, found ${PRETTY_NAME}" >&2
fi

echo "==> Installing open-vm-tools and cloud-init"
dnf -y install open-vm-tools cloud-init cloud-utils-growpart perl
systemctl enable --now vmtoolsd

echo "==> Configuring cloud-init for the VMware (guestinfo) datasource"
rm -f /etc/cloud/cloud.cfg.d/99-proxmox.cfg
cat > /etc/cloud/cloud.cfg.d/99-vmware.cfg <<'CFG'
datasource_list: [ VMware, None ]
datasource:
  VMware:
    allow_raw_data: true
# Network comes from guestinfo.metadata; do not use vSphere guest customization
disable_vmware_customization: true
growpart:
  mode: auto
  devices: ["/"]
resize_rootfs: true
preserve_hostname: false
CFG

for unit in cloud-init-local cloud-init cloud-init-network cloud-config cloud-final; do
  systemctl list-unit-files "${unit}.service" >/dev/null 2>&1 && systemctl enable "${unit}.service" || true
done

echo "==> Removing NetworkManager connections created at install time"
# cloud-init writes fresh keyfiles on the first boot of every clone
find /etc/NetworkManager/system-connections -type f -name '*.nmconnection' -delete || true

echo "==> Generalizing the image"
cloud-init clean --logs --seed
rm -f /etc/ssh/ssh_host_*
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
dnf clean all
rm -rf /tmp/* /var/tmp/*
journalctl --vacuum-time=1s >/dev/null 2>&1 || true
: > /root/.bash_history

echo "==> Done. Power off and convert the VM to a template."
