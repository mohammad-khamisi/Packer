#!/usr/bin/env bash
# Example: Prometheus node_exporter as a systemd service
set -euo pipefail
is_true() { [ "${1,,}" = "true" ]; }
# firewall-cmd when firewalld runs, firewall-offline-cmd otherwise
fw() { if systemctl is-active -q firewalld; then firewall-cmd -q --permanent "$@"; else firewall-offline-cmd "$@"; fi; }

if ! is_true "${INSTALL_NODE_EXPORTER}"; then
  echo "==> [70-node-exporter] skipped (install_node_exporter = false)"
  exit 0
fi

v="${NODE_EXPORTER_VERSION}"
echo "==> [70-node-exporter] installing node_exporter ${v}"

tmp="$(mktemp -d)"
curl -fsSL -o "${tmp}/ne.tgz" \
  "https://github.com/prometheus/node_exporter/releases/download/v${v}/node_exporter-${v}.linux-amd64.tar.gz"
tar -xzf "${tmp}/ne.tgz" -C "${tmp}"
install -m 0755 "${tmp}/node_exporter-${v}.linux-amd64/node_exporter" /usr/local/bin/node_exporter
rm -rf "${tmp}"
restorecon /usr/local/bin/node_exporter || true

id node_exporter >/dev/null 2>&1 || useradd --system --no-create-home --shell /sbin/nologin node_exporter

cat > /etc/systemd/system/node_exporter.service <<'UNIT'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable node_exporter

if is_true "${FIREWALL_ENABLED}"; then
  fw --add-port=9100/tcp
fi

echo "==> [70-node-exporter] done"
