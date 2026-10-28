# Terraform: Create VMs on VMware vSphere

**English** | [فارسی](README.fa.md)

Creates one or more virtual machines on vSphere by **cloning a template**
(for example the Rocky Linux template built with Packer in this repository),
with guest customization for hostname, static IP/DHCP, DNS and time zone.

## File layout

```text
vmware-vsphere/
├── versions.tf               # Terraform and provider versions
├── providers.tf              # vSphere provider (vCenter connection)
├── variables.tf              # All variable declarations
├── data.tf                   # Lookups: datacenter, cluster, datastore, network, template
├── main.tf                   # Folder + VM resources
├── outputs.tf                # VM IDs and IP addresses
├── terraform.tfvars.example  # ⭐ Copy to terraform.tfvars and edit
└── Makefile                  # Command shortcuts
```

## Prerequisites

- Terraform `>= 1.5`
- Access to vCenter (ESXi without vCenter does not support cloning)
- A VM template with **VMware Tools / open-vm-tools** installed
  (needed for guest customization and IP reporting); for Linux also `perl`
  is recommended for the customization engine.

## Usage

```bash
cd vmware-vsphere
cp terraform.tfvars.example terraform.tfvars   # edit values
export TF_VAR_vsphere_password='YourPassword'

terraform init
terraform plan
terraform apply
```

Or with make: `make plan` then `make apply`.

## Defining VMs

Each entry of `vms` is one VM; the key is the VM name and the hostname.
All fields are optional:

```hcl
vms = {
  "web-01" = { cpus = 2, memory_mb = 4096, disk_gb = 40, ipv4_address = "192.168.10.51" }
  "db-01"  = { cpus = 4, memory_mb = 8192, extra_disks_gb = [100], ipv4_address = "192.168.10.52" }
  "test-01" = {}   # defaults: 2 vCPU, 4 GB RAM, 40 GB disk, DHCP
}
```

Without `ipv4_address` the VM uses DHCP. Adding or removing an entry and running
`terraform apply` creates or deletes only that VM.

## Delete

```bash
terraform destroy
```

## Notes

- `terraform.tfvars` and `*.tfstate` are git-ignored – the state contains
  sensitive data; store it in a remote backend for team use.
- The OS disk can never be smaller than the template disk.
- Changes to the template do not re-create existing VMs (`ignore_changes`).
