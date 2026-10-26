#!/usr/bin/env bash
# Example: Node.js + npm from AppStream
set -euo pipefail
is_true() { [ "${1,,}" = "true" ]; }

if ! is_true "${INSTALL_NODEJS}"; then
  echo "==> [60-nodejs] skipped (install_nodejs = false)"
  exit 0
fi

echo "==> [60-nodejs] installing Node.js"
dnf -y install nodejs npm
node --version
echo "==> [60-nodejs] done"
