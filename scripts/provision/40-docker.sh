#!/usr/bin/env bash
# Example: Docker CE from the official repository
set -euo pipefail
is_true() { [ "${1,,}" = "true" ]; }

if ! is_true "${INSTALL_DOCKER}"; then
  echo "==> [40-docker] skipped (install_docker = false)"
  exit 0
fi

echo "==> [40-docker] installing Docker CE"
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'CFG'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
CFG

systemctl enable docker containerd

for u in ${DOCKER_USERS}; do
  if id "$u" >/dev/null 2>&1; then
    usermod -aG docker "$u"
  else
    echo "WARNING: user $u not found, skipped"
  fi
done

echo "==> [40-docker] done"
