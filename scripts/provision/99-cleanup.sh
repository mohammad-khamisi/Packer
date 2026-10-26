#!/usr/bin/env bash
# Generalize the image so every clone in Proxmox is unique
set -euo pipefail
is_true() { [ "${1,,}" = "true" ]; }

echo "==> [99-cleanup]"

# Build-only sshd override from the kickstart
rm -f /etc/ssh/sshd_config.d/00-packer-build.conf

# Packages / caches
dnf -y autoremove || true
dnf clean all
rm -rf /var/cache/dnf/* /tmp/packer-files

# Kickstart files (contain the build password)
rm -f /root/anaconda-ks.cfg /root/original-ks.cfg /root/ks-post.log

# Network: let NetworkManager/cloud-init create connections on first boot
rm -f /etc/NetworkManager/system-connections/*.nmconnection

# Identity: machine-id, SSH host keys, hostname
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null || true
rm -f /etc/ssh/ssh_host_*
hostnamectl set-hostname localhost.localdomain

# cloud-init state (re-run on first boot of every clone)
cloud-init clean --logs --seed || true

# Logs and history
journalctl --rotate || true
journalctl --vacuum-time=1s || true
find /var/log -type f \( -name "*.log" -o -name "*.gz" -o -name "*-[0-9]*" \) -exec truncate -s 0 {} + 2>/dev/null || true
truncate -s 0 /var/log/wtmp /var/log/lastlog /var/log/btmp 2>/dev/null || true
rm -rf /root/.bash_history /home/*/.bash_history /tmp/* /var/tmp/*

# Free space
if is_true "${ZERO_FREE_SPACE}"; then
  echo "==> Zeroing free space"
  dd if=/dev/zero of=/EMPTY bs=1M status=none || true
  rm -f /EMPTY
fi
fstrim -av || true
sync

echo "==> [99-cleanup] done"
