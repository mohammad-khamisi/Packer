#!/usr/bin/env bash
# Base settings for Rocky Linux 10.2 (runs as root after the VM is created).
set -euo pipefail
echo "==> [10-base]"

# Time sync
systemctl enable --now chronyd
chronyc makestep >/dev/null 2>&1 || true

# EPEL (optional) - uncomment if needed
# dnf -y install epel-release && /usr/bin/crb enable

# SELinux stays enforcing (Rocky default)
getenforce || true

# Firewall: keep SSH open
dnf -y install firewalld
systemctl enable --now firewalld
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

echo "==> [10-base] done"
