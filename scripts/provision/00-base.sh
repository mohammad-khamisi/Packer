#!/usr/bin/env bash
# Base system: repositories, updates, timezone, base + extra packages
set -euo pipefail
is_true() { [ "${1,,}" = "true" ]; }

echo "==> [00-base] Rocky Linux ${OS_VERSION}"

# Faster dnf
grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf || echo 'max_parallel_downloads=10' >> /etc/dnf/dnf.conf
grep -q '^fastestmirror' /etc/dnf/dnf.conf || echo 'fastestmirror=True' >> /etc/dnf/dnf.conf

dnf -y install dnf-plugins-core

if is_true "${ENABLE_EPEL}" || is_true "${INSTALL_FAIL2BAN}"; then
  echo "==> Enabling CRB and EPEL"
  dnf config-manager --set-enabled crb
  dnf -y install epel-release
fi

if is_true "${DNF_UPDATE}"; then
  echo "==> Updating system"
  dnf -y upgrade --refresh
fi

echo "==> Installing base packages: ${BASE_PACKAGES}"
# shellcheck disable=SC2086
dnf -y install ${BASE_PACKAGES}

if [ -n "${EXTRA_PACKAGES// /}" ]; then
  echo "==> Installing extra packages: ${EXTRA_PACKAGES}"
  # shellcheck disable=SC2086
  dnf -y install ${EXTRA_PACKAGES}
fi

timedatectl set-timezone "${TIMEZONE}"
systemctl enable chronyd

echo "==> [00-base] done"
