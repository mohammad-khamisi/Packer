#!/usr/bin/env bash
# Security: SELinux, firewalld, sshd hardening, fail2ban
set -euo pipefail
is_true() { [ "${1,,}" = "true" ]; }
# firewall-cmd when firewalld runs, firewall-offline-cmd otherwise
fw() { if systemctl is-active -q firewalld; then firewall-cmd -q --permanent "$@"; else firewall-offline-cmd "$@"; fi; }

echo "==> [20-security]"

# --- SELinux -------------------------------------------------------------
echo "==> SELinux mode: ${SELINUX_MODE}"
if [ "${SELINUX_MODE}" = "disabled" ]; then
  # RHEL 10: disabling SELinux is done via the kernel command line
  grubby --update-kernel ALL --args selinux=0
  sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
else
  sed -i "s/^SELINUX=.*/SELINUX=${SELINUX_MODE}/" /etc/selinux/config
fi

# --- firewalld -----------------------------------------------------------
if is_true "${FIREWALL_ENABLED}"; then
  dnf -y install firewalld
  systemctl enable firewalld
  fw --add-service=ssh
  for svc in ${FIREWALL_SERVICES}; do
    echo "==> firewall: service ${svc}"
    fw --add-service="${svc}"
  done
  for port in ${FIREWALL_PORTS}; do
    echo "==> firewall: port ${port}"
    fw --add-port="${port}"
  done
else
  systemctl disable firewalld 2>/dev/null || true
fi

# --- sshd (applies on next boot, the build session is not affected) --------
pw_auth="no"
is_true "${SSH_PASSWORD_AUTH}" && pw_auth="yes"
cat > /etc/ssh/sshd_config.d/10-hardening.conf <<CFG
# Managed by Packer
PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}
PasswordAuthentication ${pw_auth}
KbdInteractiveAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
ClientAliveInterval 300
ClientAliveCountMax 2
CFG
chmod 600 /etc/ssh/sshd_config.d/10-hardening.conf

# --- fail2ban ------------------------------------------------------------
if is_true "${INSTALL_FAIL2BAN}"; then
  echo "==> Installing fail2ban"
  dnf -y install fail2ban fail2ban-firewalld
  cat > /etc/fail2ban/jail.d/sshd.local <<'CFG'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
CFG
  systemctl enable fail2ban
fi

echo "==> [20-security] done"
