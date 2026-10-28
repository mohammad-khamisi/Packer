# Look up existing vSphere objects by name.

data "vsphere_datacenter" "this" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "this" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_datastore" "this" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_network" "this" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.this.id
}

# Source template (for example the Rocky Linux image built by Packer in this repo).
data "vsphere_virtual_machine" "template" {
  name          = var.template
  datacenter_id = data.vsphere_datacenter.this.id
}
