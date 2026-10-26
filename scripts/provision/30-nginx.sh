#!/usr/bin/env bash
# Example: Nginx web server
set -euo pipefail
is_true() { [ "${1,,}" = "true" ]; }
# firewall-cmd when firewalld runs, firewall-offline-cmd otherwise
fw() { if systemctl is-active -q firewalld; then firewall-cmd -q --permanent "$@"; else firewall-offline-cmd "$@"; fi; }

if ! is_true "${INSTALL_NGINX}"; then
  echo "==> [30-nginx] skipped (install_nginx = false)"
  exit 0
fi

echo "==> [30-nginx] installing Nginx"
dnf -y install nginx

# Example configs uploaded by the file provisioner (files/nginx/)
install -m 0644 "${FILES_DIR}/nginx/nginx.conf" /etc/nginx/nginx.conf
sed "s/__SERVER_NAME__/${NGINX_SERVER_NAME}/" "${FILES_DIR}/nginx/default.conf" > /etc/nginx/conf.d/default.conf

mkdir -p /usr/share/nginx/html
sed -e "s/__OS_VERSION__/${OS_VERSION}/" -e "s/__BUILD_DATE__/$(date -u +%F)/" \
  "${FILES_DIR}/nginx/index.html" > /usr/share/nginx/html/index.html
restorecon -R /etc/nginx /usr/share/nginx/html || true

nginx -t
systemctl enable nginx

if is_true "${FIREWALL_ENABLED}"; then
  fw --add-service=http
  fw --add-service=https
fi

echo "==> [30-nginx] done"
