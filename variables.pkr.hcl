# =============================================================================
#  Variable declarations (types, descriptions and defaults).
#  Do NOT edit values here – override them in rocky10.auto.pkrvars.hcl
#  (auto-loaded) or secrets.auto.pkrvars.hcl / PKR_VAR_* environment vars.
# =============================================================================

# -----------------------------------------------------------------------------
# OS / ISO
# -----------------------------------------------------------------------------
variable "os_version" {
  type        = string
  description = "Rocky Linux version to build (used in ISO URL and image name)."
  default     = "10.2"
}

variable "os_arch" {
  type        = string
  description = "CPU architecture of the ISO."
  default     = "x86_64"
}

variable "iso_flavor" {
  type        = string
  description = "ISO flavor: minimal | dvd1 | boot."
  default     = "minimal"

  validation {
    condition     = contains(["minimal", "dvd1", "boot"], var.iso_flavor)
    error_message = "The iso_flavor must be one of: minimal, dvd1, boot."
  }
}

variable "iso_mirror" {
  type        = string
  description = "Base URL of the Rocky Linux mirror (without trailing slash)."
  default     = "https://download.rockylinux.org/pub/rocky"
}

variable "iso_url" {
  type        = string
  description = "Full ISO URL or local path. Empty = built from mirror/version/flavor."
  default     = ""
}

variable "iso_checksum" {
  type        = string
  description = "ISO checksum (e.g. sha256:abc...) or file:URL. Empty = mirror CHECKSUM file."
  default     = ""
}

# -----------------------------------------------------------------------------
# Image naming / output
# -----------------------------------------------------------------------------
variable "image_name" {
  type        = string
  description = "Base name of the produced image / template."
  default     = "rocky"
}

variable "image_append_timestamp" {
  type        = bool
  description = "Append a timestamp (YYYYMMDD-hhmm) to the image name."
  default     = true
}

variable "output_directory" {
  type        = string
  description = "Parent directory where qcow2 build output is written."
  default     = "output"
}

# -----------------------------------------------------------------------------
# Virtual hardware (shared by both builders)
# -----------------------------------------------------------------------------
variable "cpus" {
  type        = number
  description = "Number of vCPUs for the build VM."
  default     = 2
}

variable "memory" {
  type        = number
  description = "RAM of the build VM in MB (Anaconda needs at least 2048)."
  default     = 4096
}

variable "disk_size" {
  type        = string
  description = "Disk size of the image (e.g. 20G). Proxmox can grow it later."
  default     = "20G"
}

variable "firmware" {
  type        = string
  description = "Firmware: bios (SeaBIOS) or uefi (OVMF). Must match the Proxmox VM later."
  default     = "bios"

  validation {
    condition     = contains(["bios", "uefi"], var.firmware)
    error_message = "The firmware must be either bios or uefi."
  }
}

# -----------------------------------------------------------------------------
# QEMU builder settings (qemu.rocky10)
# -----------------------------------------------------------------------------
variable "qemu_binary" {
  type        = string
  description = "QEMU binary. On a Proxmox host 'qemu-system-x86_64' or 'kvm' both work."
  default     = "qemu-system-x86_64"
}

variable "qemu_accelerator" {
  type        = string
  description = "QEMU accelerator: kvm | tcg | hvf | whpx | none."
  default     = "kvm"
}

variable "qemu_cpu_model" {
  type        = string
  description = "QEMU CPU model. Rocky 10 needs x86-64-v3; use 'host' (KVM) or 'Haswell-v4'."
  default     = "host"
}

variable "qemu_machine_type" {
  type        = string
  description = "QEMU machine type: q35 or pc."
  default     = "q35"
}

variable "qemu_disk_interface" {
  type        = string
  description = "Disk interface during build: virtio | virtio-scsi | scsi | ide | sata."
  default     = "virtio-scsi"
}

variable "qemu_disk_compression" {
  type        = bool
  description = "Compress the final qcow2 file (smaller file, slower build)."
  default     = true
}

variable "qemu_ovmf_code" {
  type        = string
  description = "OVMF CODE file path (only used when firmware = uefi)."
  default     = "/usr/share/OVMF/OVMF_CODE_4M.fd"
}

variable "qemu_ovmf_vars" {
  type        = string
  description = "OVMF VARS file path (only used when firmware = uefi)."
  default     = "/usr/share/OVMF/OVMF_VARS_4M.fd"
}

variable "headless" {
  type        = bool
  description = "Run the QEMU build without a GUI window (connect via VNC to watch)."
  default     = true
}

variable "vnc_bind_address" {
  type        = string
  description = "Address the QEMU VNC server listens on (0.0.0.0 to watch remotely)."
  default     = "127.0.0.1"
}

# -----------------------------------------------------------------------------
# Boot / Kickstart / Packer HTTP server
# -----------------------------------------------------------------------------
variable "boot_wait" {
  type        = string
  description = "Time to wait before typing the boot command."
  default     = "10s"
}

variable "boot_command" {
  type        = list(string)
  description = "Override the GRUB boot command. Empty = default (works for BIOS and UEFI)."
  default     = []
}

variable "http_bind_address" {
  type        = string
  description = "Address of Packer's HTTP server (serves ks.cfg). 0.0.0.0 = all interfaces."
  default     = "0.0.0.0"
}

variable "http_port_min" {
  type        = number
  description = "Lowest port of Packer's HTTP server (open it in your firewall for Proxmox builds)."
  default     = 8100
}

variable "http_port_max" {
  type        = number
  description = "Highest port of Packer's HTTP server."
  default     = 8150
}

variable "http_ip_override" {
  type        = string
  description = "IP the VM uses to reach Packer's HTTP server. Empty = auto (set this for Proxmox builds if auto-detection picks the wrong NIC)."
  default     = ""
}

# -----------------------------------------------------------------------------
# Guest OS settings (used in the kickstart)
# -----------------------------------------------------------------------------
variable "hostname" {
  type        = string
  description = "Hostname during the build (cloud-init resets it on Proxmox)."
  default     = "rocky10-template"
}

variable "locale" {
  type        = string
  description = "System locale."
  default     = "en_US.UTF-8"
}

variable "keyboard" {
  type        = string
  description = "Keyboard layout."
  default     = "us"
}

variable "timezone" {
  type        = string
  description = "System timezone (e.g. Asia/Tehran, UTC)."
  default     = "Asia/Tehran"
}

variable "root_password" {
  type        = string
  description = "Root password. Empty = root account locked (recommended)."
  default     = ""
  sensitive   = true
}

variable "ssh_username" {
  type        = string
  description = "Temporary build user created by kickstart and used by Packer over SSH. Do not use root."
  default     = "packer"
}

variable "ssh_password" {
  type        = string
  description = "Password of the build user (no spaces or quotes)."
  default     = "Packer@Build2026"
  sensitive   = true
}

variable "ssh_timeout" {
  type        = string
  description = "How long Packer waits for SSH (covers the whole OS installation)."
  default     = "45m"
}

variable "remove_build_user" {
  type        = bool
  description = "Delete the build user (and its sudo rule) at the end of the build."
  default     = true
}

# -----------------------------------------------------------------------------
# Provisioning: base system
# -----------------------------------------------------------------------------
variable "dnf_update" {
  type        = bool
  description = "Run 'dnf upgrade' during the build."
  default     = true
}

variable "reboot_after_update" {
  type        = bool
  description = "Reboot after the update so later steps run on the new kernel."
  default     = false
}

variable "enable_epel" {
  type        = bool
  description = "Enable EPEL + CRB repositories."
  default     = true
}

variable "base_packages" {
  type        = list(string)
  description = "Packages always installed (Proxmox integration + tools)."
  default = [
    "qemu-guest-agent",
    "cloud-init",
    "cloud-utils-growpart",
    "vim-enhanced",
    "curl",
    "wget",
    "tar",
    "unzip",
    "bash-completion",
    "chrony",
    "rsync",
    "lsof",
    "tmux",
  ]
}

variable "extra_packages" {
  type        = list(string)
  description = "Additional packages you want in the image."
  default     = ["git", "htop", "net-tools", "bind-utils", "jq"]
}

variable "custom_commands" {
  type        = list(string)
  description = "Extra shell commands run as root at the end of provisioning."
  default     = []
}

# -----------------------------------------------------------------------------
# Provisioning: security
# -----------------------------------------------------------------------------
variable "selinux_mode" {
  type        = string
  description = "SELinux mode: enforcing | permissive | disabled."
  default     = "enforcing"

  validation {
    condition     = contains(["enforcing", "permissive", "disabled"], var.selinux_mode)
    error_message = "The selinux_mode must be enforcing, permissive or disabled."
  }
}

variable "firewall_enabled" {
  type        = bool
  description = "Keep firewalld enabled in the image."
  default     = true
}

variable "firewall_services" {
  type        = list(string)
  description = "firewalld services to open (ssh is always open)."
  default     = []
}

variable "firewall_ports" {
  type        = list(string)
  description = "Extra ports to open, e.g. [\"8080/tcp\", \"53/udp\"]."
  default     = []
}

variable "ssh_permit_root_login" {
  type        = string
  description = "sshd PermitRootLogin value: no | prohibit-password | yes."
  default     = "no"
}

variable "ssh_password_authentication" {
  type        = bool
  description = "Allow SSH password login in the final image (false = keys only)."
  default     = false
}

variable "install_fail2ban" {
  type        = bool
  description = "Install and enable fail2ban for sshd (needs EPEL; enabled automatically)."
  default     = false
}

# -----------------------------------------------------------------------------
# Provisioning: example applications (toggle with true/false)
# -----------------------------------------------------------------------------
variable "install_nginx" {
  type        = bool
  description = "Install Nginx web server and open http/https."
  default     = true
}

variable "nginx_server_name" {
  type        = string
  description = "server_name for the example Nginx site."
  default     = "_"
}

variable "install_docker" {
  type        = bool
  description = "Install Docker CE from the official Docker repository."
  default     = false
}

variable "docker_users" {
  type        = list(string)
  description = "Existing users added to the docker group."
  default     = []
}

variable "install_podman" {
  type        = bool
  description = "Install Podman (Rocky native container engine)."
  default     = false
}

variable "install_postgresql" {
  type        = bool
  description = "Install and initialize PostgreSQL server."
  default     = false
}

variable "postgresql_open_firewall" {
  type        = bool
  description = "Open port 5432 for PostgreSQL."
  default     = false
}

variable "install_nodejs" {
  type        = bool
  description = "Install Node.js and npm from AppStream."
  default     = false
}

variable "install_node_exporter" {
  type        = bool
  description = "Install Prometheus node_exporter as a systemd service (port 9100)."
  default     = false
}

variable "node_exporter_version" {
  type        = string
  description = "node_exporter release version (without leading v)."
  default     = "1.9.1"
}

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
variable "zero_free_space" {
  type        = bool
  description = "Fill free space with zeros before shutdown (slower, smaller qcow2)."
  default     = false
}

# -----------------------------------------------------------------------------
# Proxmox builder settings (proxmox-iso.rocky10) – optional
# -----------------------------------------------------------------------------
variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL, e.g. https://192.168.1.10:8006/api2/json."
  default     = "https://192.168.1.10:8006/api2/json"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API token ID, e.g. packer@pve!packer."
  default     = "packer@pve!packer"
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token secret (put it in secrets.auto.pkrvars.hcl)."
  default     = ""
  sensitive   = true
}

variable "proxmox_insecure_tls" {
  type        = bool
  description = "Skip TLS verification (self-signed Proxmox certificate)."
  default     = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name to build on."
  default     = "pve"
}

variable "proxmox_vm_id" {
  type        = number
  description = "VM ID of the resulting template (0 = next free ID)."
  default     = 9000
}

variable "proxmox_iso_file" {
  type        = string
  description = "ISO already uploaded to Proxmox storage, e.g. local:iso/Rocky-10.2-x86_64-minimal.iso."
  default     = "local:iso/Rocky-10.2-x86_64-minimal.iso"
}

variable "proxmox_cpu_type" {
  type        = string
  description = "Proxmox CPU type. Rocky 10 needs x86-64-v3: use host or x86-64-v3."
  default     = "host"
}

variable "proxmox_sockets" {
  type        = number
  description = "Number of CPU sockets."
  default     = 1
}

variable "proxmox_disk_storage" {
  type        = string
  description = "Storage pool for the VM disk (e.g. local-lvm, local-zfs, ceph)."
  default     = "local-lvm"
}

variable "proxmox_disk_format" {
  type        = string
  description = "Disk format on Proxmox: raw (lvm/zfs/ceph) or qcow2 (directory storage)."
  default     = "raw"
}

variable "proxmox_efi_storage" {
  type        = string
  description = "Storage pool for the EFI disk (only when firmware = uefi)."
  default     = "local-lvm"
}

variable "proxmox_cloud_init_storage" {
  type        = string
  description = "Storage pool for the cloud-init drive."
  default     = "local-lvm"
}

variable "proxmox_bridge" {
  type        = string
  description = "Network bridge for the VM."
  default     = "vmbr0"
}

variable "proxmox_vlan_tag" {
  type        = string
  description = "VLAN tag for the NIC (empty = untagged)."
  default     = ""
}

variable "proxmox_template_description" {
  type        = string
  description = "Description shown on the Proxmox template."
  default     = "Rocky Linux 10 template built with Packer"
}
