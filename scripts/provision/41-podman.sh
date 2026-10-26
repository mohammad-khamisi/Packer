#!/usr/bin/env bash
# Example: Podman (native Rocky container engine)
set -euo pipefail
is_true() { [ "${1,,}" = "true" ]; }

if ! is_true "${INSTALL_PODMAN}"; then
  echo "==> [41-podman] skipped (install_podman = false)"
  exit 0
fi

echo "==> [41-podman] installing Podman"
dnf -y install podman buildah skopeo
systemctl enable podman.socket
echo "==> [41-podman] done"
