# cloud-init configuration passed to each VM through VMware guestinfo.
#
#   metadata -> hostname + network (static IP or DHCP)
#   userdata -> users, packages, timezone and the commands:
#                 bootcmd : early_commands      (very early on EVERY boot, before the network is up)
#                 runcmd  : first_boot_commands (once, at the end of the first boot)
#
# Keys whose value is null are dropped so the generated YAML stays clean.

locals {
  cloud_init_metadata = {
    for name, vm in var.vms : name => yamlencode({
      "instance-id"    = name
      "local-hostname" = name
      network = {
        version = 2
        ethernets = {
          nic0 = { for k, v in {
            match     = { name = "en*" }
            dhcp4     = vm.ipv4_address == null
            dhcp6     = false
            addresses = vm.ipv4_address == null ? null : ["${vm.ipv4_address}/${var.ipv4_netmask}"]
            routes    = vm.ipv4_address == null || var.ipv4_gateway == null ? null : [{ to = "default", via = var.ipv4_gateway }]
            nameservers = length(var.dns_servers) == 0 ? null : {
              addresses = var.dns_servers
              search    = var.domain == null ? [] : [var.domain]
            }
          } : k => v if v != null }
        }
      }
    })
  }

  cloud_init_userdata = {
    for name, vm in var.vms : name => "#cloud-config\n${yamlencode({
      hostname         = name
      fqdn             = var.domain == null ? name : "${name}.${var.domain}"
      manage_etc_hosts = true
      timezone         = var.time_zone

      users = [
        { for k, v in {
          name                = var.admin_user
          groups              = ["wheel"]
          shell               = "/bin/bash"
          sudo                = "ALL=(ALL) NOPASSWD:ALL"
          lock_passwd         = var.admin_password_hash == null
          passwd              = var.admin_password_hash
          ssh_authorized_keys = var.ssh_authorized_keys
        } : k => v if v != null }
      ]
      ssh_pwauth = var.admin_password_hash != null

      package_update = var.package_update
      packages       = distinct(concat(var.packages, vm.extra_packages))

      bootcmd = concat(var.early_commands, vm.early_commands)
      runcmd  = concat(var.first_boot_commands, vm.first_boot_commands)

      final_message = "cloud-init finished on ${name} after $UPTIME seconds"
    })}"
  }
}
