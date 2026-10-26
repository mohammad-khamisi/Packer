packer {
  required_version = ">= 1.10.0"

  required_plugins {
    # Builder for producing a qcow2 file locally (KVM/QEMU)
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
    # Builder for building directly on Proxmox VE (optional)
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.0"
    }
  }
}
