# Commands run over SSH by Terraform AFTER each VM has been created and
# cloud-init has finished:
#   1. every *.sh in var.post_create_scripts_dir (sorted by name)
#   2. var.post_create_commands + the VM's own post_create_commands
# All of them run as root (via sudo).

locals {
  post_create_scripts_dir = coalesce(var.post_create_scripts_dir, "${path.module}/scripts/post-create")
  post_create_scripts     = sort(fileset(local.post_create_scripts_dir, "*.sh"))
  post_create_hash        = sha1(join("", [for f in local.post_create_scripts : filesha1("${local.post_create_scripts_dir}/${f}")]))
}

resource "terraform_data" "post_create" {
  for_each = var.enable_post_create ? var.vms : {}

  # Re-run when the VM is re-created or the scripts/commands change.
  triggers_replace = [
    vsphere_virtual_machine.vm[each.key].id,
    local.post_create_hash,
    var.post_create_commands,
    each.value.post_create_commands,
  ]

  connection {
    type        = "ssh"
    host        = coalesce(each.value.ipv4_address, vsphere_virtual_machine.vm[each.key].default_ip_address)
    user        = var.admin_user
    private_key = file(pathexpand(var.ssh_private_key_path))
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait > /dev/null || true",
      "rm -rf /tmp/post-create && mkdir -p /tmp/post-create",
    ]
  }

  provisioner "file" {
    source      = "${local.post_create_scripts_dir}/"
    destination = "/tmp/post-create"
  }

  provisioner "file" {
    content     = join("\n", concat(["#!/usr/bin/env bash", "set -euo pipefail"], var.post_create_commands, each.value.post_create_commands, [""]))
    destination = "/tmp/post-create/zz-commands.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "for f in /tmp/post-create/*.sh; do echo \"==> $f\"; sudo bash \"$f\" || exit 1; done",
      "rm -rf /tmp/post-create",
    ]
  }
}
