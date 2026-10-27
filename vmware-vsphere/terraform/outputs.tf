output "masters" {
  description = "Control-plane nodes (name => IP)"
  value       = { for name in keys(var.masters) : name => vsphere_virtual_machine.node[name].default_ip_address }
}

output "workers" {
  description = "Worker nodes (name => IP)"
  value       = { for name in keys(var.workers) : name => vsphere_virtual_machine.node[name].default_ip_address }
}

output "ansible_inventory" {
  description = "Generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "vm_folder" {
  description = "vSphere folder that holds the cluster VMs"
  value       = "/${var.datacenter}/vm/${local.vm_folder_path}"
}
