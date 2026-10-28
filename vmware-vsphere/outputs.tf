output "vm_ids" {
  description = "Managed object IDs of the created VMs."
  value       = { for name, vm in vsphere_virtual_machine.vm : name => vm.moid }
}

output "vm_ip_addresses" {
  description = "Primary IP address reported by VMware Tools for each VM."
  value       = { for name, vm in vsphere_virtual_machine.vm : name => vm.default_ip_address }
}
