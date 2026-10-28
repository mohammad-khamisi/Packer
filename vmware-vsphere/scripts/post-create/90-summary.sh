#!/usr/bin/env bash
# Print a short summary of the VM.
set -euo pipefail
echo "==> [90-summary]"
. /etc/os-release
echo "Host:    $(hostname -f 2>/dev/null || hostname)"
echo "OS:      ${PRETTY_NAME}"
echo "Kernel:  $(uname -r)"
echo "IP:      $(hostname -I)"
echo "DNS:     $(awk '/^nameserver/{printf "%s ", $2}' /etc/resolv.conf)"
