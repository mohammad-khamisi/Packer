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

  # Rocky Linux 10 guest type; null falls back to the template's guest type.
  guest_id  = coalesce(var.guest_id, data.vsphere_virtual_machine.template.guest_id)
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

  # No vSphere guest customization: network, hostname, users and first-boot
  # commands are applied by cloud-init (VMware datasource) - see cloud-init.tf.
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  extra_config = {
    "guestinfo.metadata"          = base64encode(local.cloud_init_metadata[each.key])
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode(local.cloud_init_userdata[each.key])
    "guestinfo.userdata.encoding" = "base64"
  }

  lifecycle {
    # cloud-init only runs on first boot, so later changes to it (or a rebuilt
    # template) must not modify or re-create existing VMs.
    ignore_changes = [clone[0].template_uuid, extra_config]
  }
}
