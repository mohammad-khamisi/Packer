# Rocky Linux 10.2 Image for Proxmox VE with Packer

**English** | [فارسی](README.fa.md)

This repository builds a **Rocky Linux 10.2** image with **HashiCorp Packer**, ready to use in **Proxmox VE**
(includes `qemu-guest-agent`, `cloud-init` and automatic root filesystem growth).

There are two build methods (both share the same kickstart and provisioning scripts):

| Method | Source | Output | Use case |
|--------|--------|--------|----------|
| **A (main)** | `qemu.rocky10` | `qcow2` file | Build on any Linux host with KVM, then import the file into Proxmox |
| B (optional) | `proxmox-iso.rocky10` | Template inside Proxmox | Packer builds directly on Proxmox via the API |

---

## 1. File layout

```text
.
├── plugins.pkr.hcl              # Required Packer plugins (qemu and proxmox)
├── variables.pkr.hcl            # All variable declarations (type, description, default)
├── rocky10.auto.pkrvars.hcl     # ⭐ Variables file – change all settings here
├── secrets.auto.pkrvars.hcl.example  # Secrets template (copy it; never pushed)
├── rocky10.pkr.hcl              # Sources (qemu / proxmox-iso) and the build block
├── http/
│   └── ks.cfg.pkrtpl.hcl        # Kickstart (unattended install) – filled from variables
├── scripts/
│   ├── provision/               # Scripts run inside the image (in order)
│   │   ├── 00-base.sh           # Repos, updates, base + extra packages, timezone
│   │   ├── 10-proxmox-integration.sh  # qemu-guest-agent, cloud-init, serial console
│   │   ├── 20-security.sh       # SELinux, firewalld, SSH hardening, fail2ban
│   │   ├── 30-nginx.sh          # Example: Nginx
│   │   ├── 40-docker.sh         # Example: Docker CE
│   │   ├── 41-podman.sh         # Example: Podman
│   │   ├── 50-postgresql.sh     # Example: PostgreSQL
│   │   ├── 60-nodejs.sh         # Example: Node.js
│   │   ├── 70-node-exporter.sh  # Example: Prometheus node_exporter
│   │   └── 99-cleanup.sh        # Generalize the image (machine-id, SSH keys, logs...)
│   └── proxmox/
│       └── import-to-proxmox.sh # Import the qcow2 into Proxmox and convert to a template
├── files/nginx/                 # Sample config files copied into the image
└── Makefile                     # Command shortcuts
```

---

## 2. Prerequisites (method A)

A Linux host with **KVM** support (bare metal, a VM with nested virtualization, or **the Proxmox host itself**).

> ⚠️ Rocky Linux 10 only runs on **x86-64-v3** CPUs (Haswell or newer).
> That is why the `host` CPU model is used.

### Ubuntu / Debian / Proxmox

```bash
# Packer
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y packer

# QEMU/KVM and OVMF (for UEFI) – already installed on Proxmox
sudo apt install -y qemu-system-x86 qemu-utils ovmf make git

# Check KVM
ls -l /dev/kvm && grep -c -E 'vmx|svm' /proc/cpuinfo
```

### Rocky / Alma / Fedora

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install -y packer qemu-kvm qemu-img edk2-ovmf make git
```

Then set these in the variables file:

```hcl
qemu_binary    = "/usr/libexec/qemu-kvm"
qemu_ovmf_code = "/usr/share/edk2/ovmf/OVMF_CODE.fd"   # uefi only
qemu_ovmf_vars = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
```

> 💡 If `releases.hashicorp.com` or GitHub is blocked, download the Packer binary and plugins manually and install
> them with `packer plugins install --path <file> github.com/hashicorp/qemu`.

---

## 3. Step-by-step (method A – build a qcow2 file)

### Step 1: Clone the repository

```bash
git clone https://github.com/mohammad-khamisi/Packer.git
cd Packer
```

### Step 2: Edit the variables

Open `rocky10.auto.pkrvars.hcl` and change whatever you need
(version, hardware, timezone, packages, example applications, ...).

```bash
nano rocky10.auto.pkrvars.hcl
```

Put passwords in a separate file (ignored by git):

```bash
cp secrets.auto.pkrvars.hcl.example secrets.auto.pkrvars.hcl
nano secrets.auto.pkrvars.hcl
```

### Step 3: Install the plugins

```bash
packer init .
```

### Step 4: Format and validate

```bash
packer fmt .
packer validate -only='qemu.rocky10' .
```

### Step 5: Build the image

```bash
packer build -only='qemu.rocky10' .

# or with full logging:
PACKER_LOG=1 PACKER_LOG_PATH=packer-build.log packer build -only='qemu.rocky10' .

# or with the Makefile (steps 3–5):
make build
```

Duration: about 15–30 minutes (depending on bandwidth and hardware).
To watch the installation, open the VNC address Packer prints (e.g. `127.0.0.1:5947`) with a VNC viewer.

Output:

```text
output/rocky-10.2-x86_64-20261026-1200/
├── rocky-10.2-x86_64-20261026-1200.qcow2
└── rocky-10.2-x86_64-20261026-1200.sha256
output/manifest.json
```

### Step 6: Copy the file to Proxmox

```bash
scp output/rocky-10.2-x86_64-*/rocky-10.2-x86_64-*.qcow2 root@PROXMOX_IP:/root/
scp scripts/proxmox/import-to-proxmox.sh root@PROXMOX_IP:/root/
```

### Step 7: Create the template in Proxmox (on the Proxmox host)

**Automated (script):**

```bash
ssh root@PROXMOX_IP
chmod +x import-to-proxmox.sh

VMID=9000 NAME=rocky-10-template STORAGE=local-lvm BRIDGE=vmbr0 \
CI_USER=rocky CI_SSHKEY=/root/.ssh/id_rsa.pub \
  ./import-to-proxmox.sh /root/rocky-10.2-x86_64-20261026-1200.qcow2
```

All script settings (VMID, STORAGE, CORES, MEMORY, FIRMWARE, DISK_SIZE, CI_*, VLAN_TAG, ...) are documented at the
top of `scripts/proxmox/import-to-proxmox.sh`.

**Manual (equivalent to the script):**

```bash
qm create 9000 --name rocky-10-template --ostype l26 --machine q35 \
  --cpu host --cores 2 --memory 2048 --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single --serial0 socket --vga serial0 --agent enabled=1

qm disk import 9000 /root/rocky-10.2-x86_64-20261026-1200.qcow2 local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0,discard=on,iothread=1,ssd=1
qm set 9000 --boot order=scsi0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --ciuser rocky --sshkeys /root/.ssh/id_rsa.pub --ipconfig0 ip=dhcp
qm template 9000
```

> If you built with `firmware = "uefi"`, also run:
> `qm set 9000 --bios ovmf --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0`
> (On Proxmox 7 use `qm importdisk` instead of `qm disk import`.)

### Step 8: Create a VM from the template

```bash
qm clone 9000 101 --name web-01 --full
qm set 101 --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1 --nameserver 1.1.1.1
qm disk resize 101 scsi0 +20G      # optional – root partition grows automatically
qm start 101

ssh rocky@192.168.1.50
```

Or from the web UI: right-click the template → **Clone** → **Cloud-Init** tab → User / Password / SSH Key / IP → **Start**.

---

## 4. Method B – build directly on Proxmox (optional)

### Step 1: Create an API user and token (on Proxmox)

```bash
pveum user add packer@pve
pveum acl modify / --users packer@pve --roles PVEVMAdmin,PVEDatastoreAdmin,PVESDNUser
pveum user token add packer@pve packer --privsep 0
# Put the returned "value" into secrets.auto.pkrvars.hcl → proxmox_token
```

### Step 2: Upload the ISO to Proxmox

```bash
wget -P /var/lib/vz/template/iso \
  https://download.rockylinux.org/pub/rocky/10.2/isos/x86_64/Rocky-10.2-x86_64-minimal.iso
```

### Step 3: Set the `proxmox_*` variables in `rocky10.auto.pkrvars.hcl` and run

```bash
packer init .
packer validate -only='proxmox-iso.rocky10' .
packer build   -only='proxmox-iso.rocky10' .
# or: make build-proxmox
```

> ⚠️ The VM on Proxmox fetches the kickstart from Packer's own HTTP server, so the machine running Packer must be
> reachable from the VM network and ports `http_port_min`–`http_port_max` (default 8100–8150) must be open in its
> firewall. If the wrong IP is detected, set `http_ip_override`.

---

## 5. Examples – changing settings

All settings live in `rocky10.auto.pkrvars.hcl`. You can also override any variable temporarily on the command line
(the command line takes precedence over the file):

```bash
# Install Nginx + Docker + node_exporter
packer build -only='qemu.rocky10' \
  -var install_nginx=true -var install_docker=true -var install_node_exporter=true .

# 40 GB disk, 4 cores, UEFI
packer build -only='qemu.rocky10' -var disk_size=40G -var cpus=4 -var firmware=uefi .

# Use a pre-downloaded ISO
packer build -only='qemu.rocky10' \
  -var iso_url=file:///data/iso/Rocky-10.2-x86_64-minimal.iso \
  -var iso_checksum=sha256:<hash> .

# Environment variable (good for secrets)
export PKR_VAR_ssh_password='S3cure-Pass'
```

### Examples inside the variables file

```hcl
# Web server
install_nginx     = true
nginx_server_name = "example.com www.example.com"

# Containers
install_docker = true
docker_users   = []

# Database
install_postgresql       = true
postgresql_open_firewall = true

# Monitoring
install_node_exporter = true

# Custom packages and ports
extra_packages = ["git", "htop", "nmap", "redis"]
firewall_ports = ["8080/tcp", "6379/tcp"]

# Custom commands
custom_commands = [
  "systemctl enable redis",
  "echo 'vm.swappiness=10' > /etc/sysctl.d/99-swap.conf",
]
```

### Adding new software (e.g. Redis as a script)

1. Create `scripts/provision/80-redis.sh` following the pattern of the existing scripts.
2. Declare `install_redis` in `variables.pkr.hcl` and set it in `rocky10.auto.pkrvars.hcl`.
3. Add `"INSTALL_REDIS=${var.install_redis}"` to `provision_env` in `rocky10.pkr.hcl`.
4. Add the script path to the `scripts` list in the `build` block.

---

## 6. Key variables

| Variable | Default | Description |
|----------|---------|-------------|
| `os_version` | `10.2` | Rocky version |
| `iso_flavor` | `minimal` | `minimal` / `dvd1` / `boot` |
| `iso_url` / `iso_checksum` | empty | empty = auto from the official mirror |
| `cpus` / `memory` / `disk_size` | `2` / `4096` / `20G` | Build VM resources |
| `firmware` | `bios` | `bios` or `uefi` (must match the Proxmox VM) |
| `qemu_accelerator` / `qemu_cpu_model` | `kvm` / `host` | QEMU settings |
| `timezone` / `locale` / `keyboard` | `Asia/Tehran` / `en_US.UTF-8` / `us` | System settings |
| `ssh_username` / `ssh_password` | `packer` / ... | Temporary build user |
| `remove_build_user` | `true` | Delete the build user at the end |
| `root_password` | empty | empty = root locked |
| `dnf_update` / `enable_epel` | `true` / `true` | Updates and EPEL |
| `base_packages` / `extra_packages` | list | Packages |
| `selinux_mode` | `enforcing` | SELinux mode |
| `firewall_enabled` / `firewall_services` / `firewall_ports` | `true` / `[]` / `[]` | Firewall |
| `ssh_permit_root_login` / `ssh_password_authentication` | `no` / `false` | SSH hardening |
| `install_nginx` | `true` | Nginx |
| `install_docker` / `install_podman` | `false` | Containers |
| `install_postgresql` / `install_nodejs` | `false` | Database / Node.js |
| `install_node_exporter` / `install_fail2ban` | `false` | Monitoring / security |
| `custom_commands` | `[]` | Custom commands |
| `zero_free_space` | `false` | Smaller qcow2 |
| `proxmox_*` | ... | Method B only |

Every variable is fully described in `variables.pkr.hcl`.

---

## 7. Final image features

- GPT partitioning, single XFS root without LVM/swap → when you grow the disk in Proxmox, root grows automatically
- `qemu-guest-agent` (IP shown in Proxmox, clean shutdown, fstrim)
- `cloud-init` with `NoCloud` and `ConfigDrive` datasources (Proxmox Cloud-Init tab)
- Serial console on `ttyS0` (works with `--serial0 socket --vga serial0`)
- Stable NIC name `eth0` (`net.ifnames=0`)
- SELinux enforcing, firewalld enabled, SSH root login and password login disabled (configurable)
- Fully generalized: machine-id, SSH host keys, hostname, logs, network connections and cloud-init state are cleared

> 🔑 Because SSH password login is disabled by default, provide an SSH key in the Cloud-Init tab,
> or set `ssh_password_authentication = true`.

---

## 8. Troubleshooting

| Problem | Solution |
|---------|----------|
| `Fatal glibc error: CPU does not support x86-64-v3` | Set CPU to `host` or `x86-64-v3` (in Packer and in Proxmox) |
| `Could not access KVM kernel module` | KVM is not available; enable virtualization in the BIOS or nested virtualization on the hypervisor |
| Packer stuck at `Waiting for SSH` | Watch via VNC; if the installer couldn't fetch ks.cfg, check firewall ports 8100–8150 or `http_ip_override` |
| GRUB menu is not edited correctly | Increase `boot_wait` (e.g. `20s`) or override `boot_command` in the variables file |
| Checksum error | Set `iso_checksum` manually from the mirror's `CHECKSUM` file |
| 10.2 not on the mirror | Old releases move to `https://dl.rockylinux.org/vault/rocky`; change `iso_mirror` |
| VM won't boot in Proxmox | The build `firmware` must match BIOS/UEFI on the VM, and `boot order=scsi0` must be set |
| `output directory already exists` | `make clean` or `packer build -force ...` |

Full logs: `PACKER_LOG=1 packer build ...` — pause on error to debug: `packer build -on-error=ask ...`
