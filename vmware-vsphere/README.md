# Terraform: Rocky Linux 10.2 VMs on VMware vSphere

**English** | [فارسی](README.fa.md)

Creates one or more **Rocky Linux 10.2** virtual machines on vSphere by cloning a template.
Configuration happens in three stages:

| Stage | When | Mechanism | Variables |
|-------|------|-----------|-----------|
| 1. Early | Every boot, before the network | cloud-init `bootcmd` | `early_commands` |
| 2. First boot | Once: network, hostname, user, packages, then commands | cloud-init (VMware guestinfo) `runcmd` | `ipv4_*`, `dns_servers`, `packages`, `first_boot_commands` |
| 3. After creation | Terraform connects over SSH when cloud-init finishes | `scripts/post-create/*.sh` + commands (as root) | `post_create_commands` |

Every command variable also exists per VM inside `vms` (`early_commands`, `first_boot_commands`,
`post_create_commands`, `extra_packages`) and runs after the global ones.

## File layout

```text
vmware-vsphere/
├── versions.tf / providers.tf   # Terraform, provider and vCenter connection
├── variables.tf                 # All variables
├── data.tf                      # Datacenter, cluster, datastore, network, template lookups
├── main.tf                      # Folder + VMs
├── cloud-init.tf                # cloud-init metadata (network) and userdata (users, packages, commands)
├── post-create.tf               # SSH stage after creation
├── outputs.tf                   # IDs, IPs, ssh commands
├── terraform.tfvars.example     # ⭐ Copy to terraform.tfvars and edit
└── scripts/
    ├── prepare-template.sh      # Run once inside the Rocky 10.2 template VM
    └── post-create/             # *.sh run in name order after creation
        ├── 10-base.sh           # chrony, firewalld
        ├── 20-network.sh        # nmcli examples, sysctl tuning
        └── 90-summary.sh        # Print host/OS/IP
```

## 1. Prepare the Rocky Linux 10.2 template (once)

1. Install Rocky Linux 10.2 in a VM on vSphere (vSphere 8+: guest OS *Rocky Linux (64-bit)*).
2. Copy `scripts/prepare-template.sh` into it and run:
   ```bash
   sudo bash prepare-template.sh && sudo poweroff
   ```
   It installs `open-vm-tools` + `cloud-init`, enables the VMware datasource and generalizes the VM.
3. In vCenter: *Convert to Template*. Put its name in `template`.

> The Proxmox image built by Packer in the repository root uses `qemu-guest-agent` and the NoCloud
> datasource, so it is not suitable for vSphere without this script.

## 2. Create the VMs

```bash
cd vmware-vsphere
cp terraform.tfvars.example terraform.tfvars   # edit values
export TF_VAR_vsphere_password='YourPassword'

terraform init
terraform plan
terraform apply
```

Or with make: `make plan` then `make apply`. Delete with `terraform destroy`.

## Defining VMs

```hcl
vms = {
  "web-01" = {
    cpus = 2, memory_mb = 4096, disk_gb = 40, ipv4_address = "192.168.10.51"
    extra_packages       = ["nginx"]
    post_create_commands = ["systemctl enable --now nginx"]
  }
  "test-01" = {}   # defaults: 2 vCPU, 4 GB RAM, 40 GB disk, DHCP
}
```

Without `ipv4_address` the VM uses DHCP.

## Notes

- The post-create stage needs SSH from the machine running Terraform to the VMs, with the private key
  `ssh_private_key_path` matching one of `ssh_authorized_keys`. Disable it with `enable_post_create = false`.
- Changing a script or `post_create_commands` re-runs the post-create stage on `apply` (scripts should be idempotent).
- cloud-init settings only apply on first boot; changing them later does not touch existing VMs.
- `terraform.tfvars` and `*.tfstate` are git-ignored (the state contains sensitive data).
