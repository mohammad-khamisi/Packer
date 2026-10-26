#!/usr/bin/env bash
# Example: PostgreSQL server
set -euo pipefail
is_true() { [ "${1,,}" = "true" ]; }
# firewall-cmd when firewalld runs, firewall-offline-cmd otherwise
fw() { if systemctl is-active -q firewalld; then firewall-cmd -q --permanent "$@"; else firewall-offline-cmd "$@"; fi; }

if ! is_true "${INSTALL_POSTGRESQL}"; then
  echo "==> [50-postgresql] skipped (install_postgresql = false)"
  exit 0
fi

echo "==> [50-postgresql] installing PostgreSQL"
dnf -y install postgresql-server postgresql-contrib
if [ ! -f /var/lib/pgsql/data/PG_VERSION ]; then
  postgresql-setup --initdb
fi
systemctl enable postgresql

if is_true "${POSTGRESQL_OPEN_FIREWALL}" && is_true "${FIREWALL_ENABLED}"; then
  fw --add-service=postgresql
fi

echo "==> [50-postgresql] done (remember to edit pg_hba.conf / listen_addresses for remote access)"
