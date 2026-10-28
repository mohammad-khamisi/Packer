resource "vsphere_folder" "this" {
  count = var.create_folder && var.folder != null ? 1 : 0

  path          = var.folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.this.id
}

resource "vsphere_virtual_machine" "vm" {
  for_each = var.vms

  name             = each.key
  resource_pool_id = data.vsphere_compute_cluster.this.resource_pool_id
  datastore_id     = data.vsphere_datastore.this.id
  folder           = try(vsphere_folder.this[0].path, var.folder)
  annotation       = each.value.annotation

  num_cpus = each.value.cpus
  memory   = each.value.memory_mb

  # Inherit hardware settings from the template.
  guest_id  = data.vsphere_virtual_machine.template.guest_id
  firmware  = data.vsphere_virtual_machine.template.firmware
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout

  network_interface {
    network_id   = data.vsphere_network.this.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  # OS disk: never smaller than the template disk.
  disk {
    label            = "disk0"
    unit_number      = 0
    size             = max(each.value.disk_gb, data.vsphere_virtual_machine.template.disks[0].size)
    thin_provisioned = var.thin_provisioned
  }

  dynamic "disk" {
    for_each = each.value.extra_disks_gb
    content {
      label            = "disk${disk.key + 1}"
      unit_number      = disk.key + 1
      size             = disk.value
      thin_provisioned = var.thin_provisioned
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      timeout = var.customize_timeout

      linux_options {
        host_name = each.key
        domain    = var.domain
        time_zone = var.time_zone
      }

      # Static IP when ipv4_address is set, otherwise DHCP.
      network_interface {
        ipv4_address = each.value.ipv4_address
        ipv4_netmask = each.value.ipv4_address != null ? var.ipv4_netmask : null
      }

      ipv4_gateway    = var.ipv4_gateway
      dns_server_list = var.dns_servers
      dns_suffix_list = var.domain != null ? [var.domain] : []
    }
  }

  lifecycle {
    # Avoid re-creating VMs when the template is rebuilt/replaced.
    ignore_changes = [clone[0].template_uuid]
  }
}
