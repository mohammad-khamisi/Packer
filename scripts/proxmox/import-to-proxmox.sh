#!/usr/bin/env bash
# =============================================================================
#  Import the Packer qcow2 image into Proxmox VE and turn it into a template.
#  Run on the Proxmox host as root:
#    ./import-to-proxmox.sh /root/rocky-10.2-x86_64-20261026-1200.qcow2
#  Every setting below can be overridden with an environment variable, e.g.:
#    VMID=9001 STORAGE=local-zfs ./import-to-proxmox.sh image.qcow2
# =============================================================================
set -euo pipefail

IMAGE="${1:-${IMAGE:-}}"
VMID="${VMID:-9000}"
NAME="${NAME:-rocky-10-template}"
STORAGE="${STORAGE:-local-lvm}"          # disk storage (local-lvm, local-zfs, ceph...)
BRIDGE="${BRIDGE:-vmbr0}"
VLAN_TAG="${VLAN_TAG:-}"                  # empty = untagged
CORES="${CORES:-2}"
SOCKETS="${SOCKETS:-1}"
MEMORY="${MEMORY:-2048}"
CPU_TYPE="${CPU_TYPE:-host}"              # Rocky 10 needs x86-64-v3: host or x86-64-v3
FIRMWARE="${FIRMWARE:-bios}"              # must match var.firmware used in the build
DISK_SIZE="${DISK_SIZE:-}"                # e.g. 40G to grow the disk (empty = keep)
CI_USER="${CI_USER:-rocky}"               # cloud-init user
CI_PASSWORD="${CI_PASSWORD:-}"            # cloud-init password (optional)
CI_SSHKEY="${CI_SSHKEY:-}"                # path to a public key file (recommended)
CI_IPCONFIG="${CI_IPCONFIG:-ip=dhcp}"     # e.g. ip=192.168.1.50/24,gw=192.168.1.1
CI_DNS="${CI_DNS:-}"                      # e.g. 1.1.1.1
MAKE_TEMPLATE="${MAKE_TEMPLATE:-true}"

[ -n "${IMAGE}" ] && [ -f "${IMAGE}" ] || { echo "Usage: $0 <image.qcow2>"; exit 1; }
if qm status "${VMID}" >/dev/null 2>&1; then
  echo "VM ${VMID} already exists – choose another VMID or remove it first (qm destroy ${VMID})."
  exit 1
fi

net="virtio,bridge=${BRIDGE}"
[ -n "${VLAN_TAG}" ] && net="${net},tag=${VLAN_TAG}"

echo "==> Creating VM ${VMID} (${NAME})"
qm create "${VMID}" \
  --name "${NAME}" \
  --ostype l26 \
  --machine q35 \
  --cpu "${CPU_TYPE}" --sockets "${SOCKETS}" --cores "${CORES}" \
  --memory "${MEMORY}" \
  --net0 "${net}" \
  --scsihw virtio-scsi-single \
  --serial0 socket --vga serial0 \
  --agent enabled=1,fstrim_cloned_disks=1 \
  --tags "rocky;rocky10;packer"

if [ "${FIRMWARE}" = "uefi" ]; then
  qm set "${VMID}" --bios ovmf --efidisk0 "${STORAGE}:1,efitype=4m,pre-enrolled-keys=0"
fi

echo "==> Importing disk"
qm disk import "${VMID}" "${IMAGE}" "${STORAGE}"
disk="$(qm config "${VMID}" | awk -F': ' '/^unused0/ {print $2}')"
qm set "${VMID}" --scsi0 "${disk},discard=on,iothread=1,ssd=1"
qm set "${VMID}" --boot order=scsi0

[ -n "${DISK_SIZE}" ] && qm disk resize "${VMID}" scsi0 "${DISK_SIZE}"

echo "==> Adding cloud-init drive"
qm set "${VMID}" --ide2 "${STORAGE}:cloudinit"
qm set "${VMID}" --ciuser "${CI_USER}" --ipconfig0 "${CI_IPCONFIG}"
[ -n "${CI_PASSWORD}" ] && qm set "${VMID}" --cipassword "${CI_PASSWORD}"
[ -n "${CI_SSHKEY}" ] && qm set "${VMID}" --sshkeys "${CI_SSHKEY}"
[ -n "${CI_DNS}" ] && qm set "${VMID}" --nameserver "${CI_DNS}"

if [ "${MAKE_TEMPLATE}" = "true" ]; then
  echo "==> Converting to template"
  qm template "${VMID}"
fi

echo "==> Done. Clone it with:"
echo "    qm clone ${VMID} 101 --name rocky-web-01 --full"
echo "    qm set 101 --ipconfig0 ip=dhcp && qm start 101"
