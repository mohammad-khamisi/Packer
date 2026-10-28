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
    cpus           = optional(number, 2)
    memory_mb      = optional(number, 4096)
    disk_gb        = optional(number, 40)
    extra_disks_gb = optional(list(number), [])
    ipv4_address   = optional(string)
    annotation     = optional(string, "Managed by Terraform")
  }))

  validation {
    condition     = length(var.vms) > 0
    error_message = "Define at least one VM in var.vms."
  }
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
# Guest customization
# ---------------------------------------------------------------------------

variable "domain" {
  description = "DNS domain for the guests."
  type        = string
  default     = "local"
}

variable "time_zone" {
  description = "Guest time zone."
  type        = string
  default     = "Asia/Tehran"
}

variable "ipv4_netmask" {
  description = "Prefix length for static IPs (e.g. 24)."
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "Default gateway for static IPs. null when using DHCP."
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "DNS servers for the guests."
  type        = list(string)
  default     = []
}

variable "customize_timeout" {
  description = "Minutes to wait for guest customization to finish."
  type        = number
  default     = 10
}
