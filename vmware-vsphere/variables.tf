# ---------------------------------------------------------------------------
# vCenter connection
# ---------------------------------------------------------------------------

variable "vsphere_server" {
  description = "vCenter server FQDN or IP address."
  type        = string
}

variable "vsphere_user" {
  description = "vCenter username (e.g. administrator@vsphere.local)."
  type        = string
}

variable "vsphere_password" {
  description = "vCenter password. Prefer the TF_VAR_vsphere_password environment variable."
  type        = string
  sensitive   = true
}

variable "vsphere_allow_unverified_ssl" {
  description = "Allow self-signed vCenter certificates."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# vSphere inventory
# ---------------------------------------------------------------------------

variable "datacenter" {
  description = "Datacenter name."
  type        = string
}

variable "cluster" {
  description = "Compute cluster name."
  type        = string
}

variable "datastore" {
  description = "Datastore name for the VM disks."
  type        = string
}

variable "network" {
  description = "Port group name (e.g. \"VM Network\")."
  type        = string
}

variable "template" {
  description = "Name of the VM template to clone (must have VMware Tools / open-vm-tools)."
  type        = string
}

variable "folder" {
  description = "VM folder path relative to the datacenter's vm folder. null = root."
  type        = string
  default     = null
}

variable "create_folder" {
  description = "Create the folder given in var.folder."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Virtual machines
# ---------------------------------------------------------------------------

variable "vms" {
  description = "VMs to create, keyed by VM name (also used as hostname). Omit ipv4_address for DHCP."
  type = map(object({
    cpus                 = optional(number, 2)
    memory_mb            = optional(number, 4096)
    disk_gb              = optional(number, 40)
    extra_disks_gb       = optional(list(number), [])
    ipv4_address         = optional(string)
    annotation           = optional(string, "Rocky Linux 10.2 - managed by Terraform")
    extra_packages       = optional(list(string), [])
    early_commands       = optional(list(string), [])
    first_boot_commands  = optional(list(string), [])
    post_create_commands = optional(list(string), [])
  }))

  validation {
    condition     = length(var.vms) > 0
    error_message = "Define at least one VM in var.vms."
  }
}

variable "guest_id" {
  description = "vSphere guest OS type. rockylinux_64Guest needs vSphere 8.0+; on vSphere 7 use \"centos9_64Guest\" or null (= template's)."
  type        = string
  default     = "rockylinux_64Guest"
}

variable "thin_provisioned" {
  description = "Use thin-provisioned disks."
  type        = bool
  default     = true
}

variable "wait_for_guest_net_timeout" {
  description = "Minutes to wait for the guest to report an IP (0 disables waiting)."
  type        = number
  default     = 5
}

# ---------------------------------------------------------------------------
# Network (applied by cloud-init on first boot)
# ---------------------------------------------------------------------------

variable "domain" {
  description = "DNS domain / search domain for the guests. null = none."
  type        = string
  default     = "local"
}

variable "ipv4_netmask" {
  description = "Prefix length for static IPs (e.g. 24)."
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "Default gateway for static IPs."
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "DNS servers for the guests (empty = take them from DHCP)."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Guest OS (cloud-init)
# ---------------------------------------------------------------------------

variable "time_zone" {
  description = "Guest time zone."
  type        = string
  default     = "Asia/Tehran"
}

variable "admin_user" {
  description = "User created by cloud-init (sudo without password). Also used for the SSH connection."
  type        = string
  default     = "rocky"
}

variable "admin_password_hash" {
  description = "Optional password hash for admin_user (openssl passwd -6). null = SSH key login only."
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_authorized_keys" {
  description = "Public SSH keys for admin_user."
  type        = list(string)
  default     = []
}

variable "package_update" {
  description = "Run dnf update on first boot."
  type        = bool
  default     = true
}

variable "packages" {
  description = "Packages installed on first boot (all VMs)."
  type        = list(string)
  default     = ["vim-enhanced", "bash-completion", "chrony", "tar", "curl", "wget"]
}

variable "early_commands" {
  description = "Commands run very early on every boot, before the network is up (cloud-init bootcmd)."
  type        = list(string)
  default     = []
}

variable "first_boot_commands" {
  description = "Commands run once at the end of the first boot (cloud-init runcmd)."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Post-create (Terraform runs these over SSH after the VM is ready)
# ---------------------------------------------------------------------------

variable "enable_post_create" {
  description = "Run post-create scripts/commands over SSH after each VM is created."
  type        = bool
  default     = true
}

variable "ssh_private_key_path" {
  description = "Private key matching one of ssh_authorized_keys (used for post-create)."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "post_create_scripts_dir" {
  description = "Directory with *.sh scripts run (as root, sorted by name) after creation. null = ./scripts/post-create."
  type        = string
  default     = null
}

variable "post_create_commands" {
  description = "Extra shell commands run (as root) after the scripts, on every VM."
  type        = list(string)
  default     = []
}
