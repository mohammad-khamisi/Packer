#######################################
# vCenter connection
#######################################
variable "vsphere_server" {
  description = "vCenter address (FQDN or IP)"
  type        = string
}

variable "vsphere_user" {
  description = "vCenter username, e.g. administrator@vsphere.local"
  type        = string
}

variable "vsphere_password" {
  description = "vCenter password"
  type        = string
  sensitive   = true
}

variable "vsphere_allow_unverified_ssl" {
  description = "Accept a self-signed vCenter certificate"
  type        = bool
  default     = true
}

#######################################
# vSphere inventory
#######################################
variable "datacenter" {
  description = "Datacenter name"
  type        = string
}

variable "cluster" {
  description = "Compute cluster name (DRS cluster)"
  type        = string
}

variable "datastore" {
  description = "Datastore that holds the VM disks"
  type        = string
}

variable "network" {
  description = "Port group the VMs are attached to"
  type        = string
}

variable "template" {
  description = "VM template to clone (path relative to the datacenter, e.g. templates/rocky10)"
  type        = string
}

variable "vm_folder" {
  description = "VM folder created for the cluster (empty = datacenter root)"
  type        = string
  default     = "kubernetes"
}

variable "resource_pool" {
  description = "Resource pool path (empty = cluster root resource pool)"
  type        = string
  default     = ""
}

variable "enable_anti_affinity" {
  description = "Create DRS anti-affinity rules so masters (and workers) run on different ESXi hosts"
  type        = bool
  default     = true
}

#######################################
# Kubernetes nodes
#######################################
variable "cluster_name" {
  description = "Kubernetes cluster name (used for folder / DRS rule names)"
  type        = string
  default     = "k8s"
}

variable "masters" {
  description = "Control-plane nodes: name => settings. Use 1 or 3 (odd number) masters."
  type = map(object({
    ip        = string
    num_cpus  = optional(number)
    memory    = optional(number)
    disk_size = optional(number)
  }))
}

variable "workers" {
  description = "Worker nodes: name => settings"
  type = map(object({
    ip        = string
    num_cpus  = optional(number)
    memory    = optional(number)
    disk_size = optional(number)
  }))
}

variable "master_defaults" {
  description = "Default hardware for masters (memory in MB, disk in GB)"
  type = object({
    num_cpus  = number
    memory    = number
    disk_size = number
  })
  default = {
    num_cpus  = 2
    memory    = 4096
    disk_size = 50
  }
}

variable "worker_defaults" {
  description = "Default hardware for workers (memory in MB, disk in GB)"
  type = object({
    num_cpus  = number
    memory    = number
    disk_size = number
  })
  default = {
    num_cpus  = 4
    memory    = 8192
    disk_size = 100
  }
}

#######################################
# Guest network / access
#######################################
variable "ipv4_netmask" {
  description = "Prefix length of the node network, e.g. 24"
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "Default gateway"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["8.8.8.8", "1.1.1.1"]
}

variable "domain" {
  description = "DNS domain / search suffix"
  type        = string
  default     = "local"
}

variable "customization_method" {
  description = <<-EOT
    How the cloned VM gets its hostname / IP:
      "cloud-init" - VMware guestinfo datasource (template needs cloud-init); also injects the SSH user and key
      "vmware"     - classic vSphere guest customization (template needs open-vm-tools; user/key must already be in the template)
  EOT
  type        = string
  default     = "cloud-init"

  validation {
    condition     = contains(["cloud-init", "vmware"], var.customization_method)
    error_message = "customization_method must be \"cloud-init\" or \"vmware\"."
  }
}

variable "ssh_user" {
  description = "User Ansible connects with (created by cloud-init)"
  type        = string
  default     = "ansible"
}

variable "ssh_public_key_file" {
  description = "Public key placed in the authorized_keys of ssh_user"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_file" {
  description = "Private key written into the generated Ansible inventory"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "timezone" {
  description = "Guest time zone"
  type        = string
  default     = "Asia/Tehran"
}

#######################################
# Ansible inventory generation
#######################################
variable "ansible_inventory_path" {
  description = "Where the generated Ansible inventory is written"
  type        = string
  default     = "../ansible/inventory/hosts.ini"
}
