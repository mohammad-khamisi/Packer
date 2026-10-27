#######################################
# Lookups
#######################################
data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "ds" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "net" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  count         = var.resource_pool == "" ? 0 : 1
  name          = var.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_folder" "k8s" {
  count         = var.vm_folder == "" ? 0 : 1
  path          = var.vm_folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}

#######################################
# Node list (masters + workers)
#######################################
locals {
  resource_pool_id = var.resource_pool == "" ? data.vsphere_compute_cluster.cluster.resource_pool_id : data.vsphere_resource_pool.pool[0].id
  ssh_public_key   = trimspace(file(pathexpand(var.ssh_public_key_file)))

  nodes = merge(
    { for name, n in var.masters : name => {
      role      = "master"
      ip        = n.ip
      num_cpus  = coalesce(n.num_cpus, var.master_defaults.num_cpus)
      memory    = coalesce(n.memory, var.master_defaults.memory)
      disk_size = coalesce(n.disk_size, var.master_defaults.disk_size)
    } },
    { for name, n in var.workers : name => {
      role      = "worker"
      ip        = n.ip
      num_cpus  = coalesce(n.num_cpus, var.worker_defaults.num_cpus)
      memory    = coalesce(n.memory, var.worker_defaults.memory)
      disk_size = coalesce(n.disk_size, var.worker_defaults.disk_size)
    } },
  )

  # cloud-init (VMware guestinfo datasource) metadata: hostname + static IP
  cloudinit_metadata = { for name, n in local.nodes : name => yamlencode({
    "instance-id"    = name
    "local-hostname" = name
    network = {
      version = 2
      ethernets = {
        nic0 = {
          match       = { name = "e*" }
          dhcp4       = false
          dhcp6       = false
          addresses   = ["${n.ip}/${var.ipv4_netmask}"]
          routes      = [{ to = "default", via = var.ipv4_gateway }]
          nameservers = { addresses = var.dns_servers, search = [var.domain] }
        }
      }
    }
  }) }

  cloudinit_userdata = { for name, n in local.nodes : name => "#cloud-config\n${yamlencode({
    hostname         = name
    fqdn             = "${name}.${var.domain}"
    manage_etc_hosts = true
    timezone         = var.timezone
    users = [{
      name                = var.ssh_user
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      shell               = "/bin/bash"
      lock_passwd         = true
      ssh_authorized_keys = [local.ssh_public_key]
    }]
    ssh_pwauth = false
  })}" }
}

#######################################
# Virtual machines
#######################################
resource "vsphere_virtual_machine" "node" {
  for_each = local.nodes

  name             = each.key
  folder           = var.vm_folder == "" ? null : vsphere_folder.k8s[0].path
  resource_pool_id = local.resource_pool_id
  datastore_id     = data.vsphere_datastore.ds.id

  num_cpus = each.value.num_cpus
  memory   = each.value.memory
  guest_id = data.vsphere_virtual_machine.template.guest_id
  firmware = data.vsphere_virtual_machine.template.firmware

  scsi_type                  = data.vsphere_virtual_machine.template.scsi_type
  cpu_hot_add_enabled        = true
  memory_hot_add_enabled     = true
  enable_disk_uuid           = true # needed by the vSphere CSI driver
  wait_for_guest_net_timeout = 10

  network_interface {
    network_id   = data.vsphere_network.net.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = max(each.value.disk_size, data.vsphere_virtual_machine.template.disks[0].size)
    thin_provisioned = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks[0].eagerly_scrub
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    dynamic "customize" {
      for_each = var.customization_method == "vmware" ? [1] : []
      content {
        linux_options {
          host_name = each.key
          domain    = var.domain
          time_zone = var.timezone
        }

        network_interface {
          ipv4_address = each.value.ip
          ipv4_netmask = var.ipv4_netmask
        }

        ipv4_gateway    = var.ipv4_gateway
        dns_server_list = var.dns_servers
        dns_suffix_list = [var.domain]
      }
    }
  }

  extra_config = var.customization_method == "cloud-init" ? {
    "guestinfo.metadata"          = base64encode(local.cloudinit_metadata[each.key])
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode(local.cloudinit_userdata[each.key])
    "guestinfo.userdata.encoding" = "base64"
  } : {}

  lifecycle {
    # Template updates must not recreate running nodes
    ignore_changes = [clone[0].template_uuid, extra_config]
  }
}

#######################################
# DRS anti-affinity (spread nodes across ESXi hosts)
#######################################
resource "vsphere_compute_cluster_vm_anti_affinity_rule" "masters" {
  count               = var.enable_anti_affinity && length(var.masters) > 1 ? 1 : 0
  name                = "${var.cluster_name}-masters-anti-affinity"
  compute_cluster_id  = data.vsphere_compute_cluster.cluster.id
  virtual_machine_ids = [for name in keys(var.masters) : vsphere_virtual_machine.node[name].id]
}

resource "vsphere_compute_cluster_vm_anti_affinity_rule" "workers" {
  count               = var.enable_anti_affinity && length(var.workers) > 1 ? 1 : 0
  name                = "${var.cluster_name}-workers-anti-affinity"
  compute_cluster_id  = data.vsphere_compute_cluster.cluster.id
  virtual_machine_ids = [for name in keys(var.workers) : vsphere_virtual_machine.node[name].id]
}

#######################################
# Ansible inventory
#######################################
resource "local_file" "ansible_inventory" {
  filename        = var.ansible_inventory_path
  file_permission = "0644"
  content = templatefile("${path.module}/templates/hosts.ini.tftpl", {
    masters              = { for name in keys(var.masters) : name => local.nodes[name].ip }
    workers              = { for name in keys(var.workers) : name => local.nodes[name].ip }
    ssh_user             = var.ssh_user
    ssh_private_key_file = var.ssh_private_key_file
  })

  depends_on = [vsphere_virtual_machine.node]
}
