# =============================================================================
#  Rocky Linux 10 image for Proxmox VE
#
#  Two sources share the same kickstart and provisioning:
#    - qemu.rocky10         -> builds a .qcow2 file locally (import into Proxmox)
#    - proxmox-iso.rocky10  -> builds a template directly on a Proxmox node
#
#  Build only the qcow2 file:   packer build -only='qemu.rocky10' .
#  Build directly on Proxmox:   packer build -only='proxmox-iso.rocky10' .
# =============================================================================

locals {
  timestamp  = formatdate("YYYYMMDD-hhmm", timestamp())
  image_base = "${var.image_name}-${var.os_version}-${var.os_arch}"
  image_name = var.image_append_timestamp ? "${local.image_base}-${local.timestamp}" : local.image_base
  # Proxmox VM names must be valid DNS names (no dots / underscores)
  pve_name = replace(replace(local.image_name, ".", "-"), "_", "-")

  iso_dir      = "${var.iso_mirror}/${var.os_version}/isos/${var.os_arch}"
  iso_url      = var.iso_url != "" ? var.iso_url : "${local.iso_dir}/Rocky-${var.os_version}-${var.os_arch}-${var.iso_flavor}.iso"
  iso_checksum = var.iso_checksum != "" ? var.iso_checksum : "file:${local.iso_dir}/CHECKSUM"

  # Kickstart rendered from a template so every value comes from variables
  kickstart = templatefile("${path.root}/http/ks.cfg.pkrtpl.hcl", {
    locale        = var.locale
    keyboard      = var.keyboard
    timezone      = var.timezone
    hostname      = var.hostname
    root_password = var.root_password
    ssh_username  = var.ssh_username
    ssh_password  = var.ssh_password
    selinux_mode  = var.selinux_mode == "disabled" ? "permissive" : var.selinux_mode
    firewall      = var.firewall_enabled
  })

  http_ip = var.http_ip_override != "" ? var.http_ip_override : "{{ .HTTPIP }}"
  ks_url  = "http://${local.http_ip}:{{ .HTTPPort }}/ks.cfg"

  # GRUB (used by Rocky 10 ISOs for both BIOS and UEFI):
  # select "Install Rocky Linux", edit the entry, append kickstart args, boot with Ctrl+X
  default_boot_command = [
    "<wait><up><wait>",
    "e<wait>",
    "<down><down><end><wait>",
    " inst.text inst.ks=${local.ks_url}",
    "<wait><leftCtrlOn>x<leftCtrlOff>",
  ]
  boot_command = length(var.boot_command) > 0 ? var.boot_command : local.default_boot_command

  shutdown_command = var.remove_build_user ? "sudo sh -c 'userdel -rf ${var.ssh_username} ; rm -f /etc/sudoers.d/${var.ssh_username} ; shutdown -P now'" : "sudo shutdown -P now"

  # Environment passed to every provisioning script
  provision_env = [
    "BUILD_USER=${var.ssh_username}",
    "OS_VERSION=${var.os_version}",
    "TIMEZONE=${var.timezone}",
    "DNF_UPDATE=${var.dnf_update}",
    "ENABLE_EPEL=${var.enable_epel}",
    "BASE_PACKAGES=${join(" ", var.base_packages)}",
    "EXTRA_PACKAGES=${join(" ", var.extra_packages)}",
    "SELINUX_MODE=${var.selinux_mode}",
    "FIREWALL_ENABLED=${var.firewall_enabled}",
    "FIREWALL_SERVICES=${join(" ", var.firewall_services)}",
    "FIREWALL_PORTS=${join(" ", var.firewall_ports)}",
    "SSH_PERMIT_ROOT_LOGIN=${var.ssh_permit_root_login}",
    "SSH_PASSWORD_AUTH=${var.ssh_password_authentication}",
    "INSTALL_FAIL2BAN=${var.install_fail2ban}",
    "INSTALL_NGINX=${var.install_nginx}",
    "NGINX_SERVER_NAME=${var.nginx_server_name}",
    "INSTALL_DOCKER=${var.install_docker}",
    "DOCKER_USERS=${join(" ", var.docker_users)}",
    "INSTALL_PODMAN=${var.install_podman}",
    "INSTALL_POSTGRESQL=${var.install_postgresql}",
    "POSTGRESQL_OPEN_FIREWALL=${var.postgresql_open_firewall}",
    "INSTALL_NODEJS=${var.install_nodejs}",
    "INSTALL_NODE_EXPORTER=${var.install_node_exporter}",
    "NODE_EXPORTER_VERSION=${var.node_exporter_version}",
    "ZERO_FREE_SPACE=${var.zero_free_space}",
    "FILES_DIR=/tmp/packer-files",
  ]

  sudo_execute = "chmod +x '{{ .Path }}'; sudo -E env {{ .Vars }} bash '{{ .Path }}'"
}

# -----------------------------------------------------------------------------
# Source 1: local QEMU/KVM -> qcow2 file
# -----------------------------------------------------------------------------
source "qemu" "rocky10" {
  vm_name          = "${local.image_name}.qcow2"
  output_directory = "${var.output_directory}/${local.image_name}"

  iso_url      = local.iso_url
  iso_checksum = local.iso_checksum

  qemu_binary  = var.qemu_binary
  accelerator  = var.qemu_accelerator
  cpu_model    = var.qemu_cpu_model
  machine_type = var.qemu_machine_type
  cpus         = var.cpus
  memory       = var.memory

  format             = "qcow2"
  disk_size          = var.disk_size
  disk_interface     = var.qemu_disk_interface
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = var.qemu_disk_compression
  net_device         = "virtio-net"

  efi_boot          = var.firmware == "uefi"
  efi_firmware_code = var.firmware == "uefi" ? var.qemu_ovmf_code : null
  efi_firmware_vars = var.firmware == "uefi" ? var.qemu_ovmf_vars : null

  headless         = var.headless
  vnc_bind_address = var.vnc_bind_address

  http_content      = { "/ks.cfg" = local.kickstart }
  http_bind_address = var.http_bind_address
  http_port_min     = var.http_port_min
  http_port_max     = var.http_port_max

  boot_wait    = var.boot_wait
  boot_command = local.boot_command

  communicator = "ssh"
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = var.ssh_timeout

  shutdown_command = local.shutdown_command
  shutdown_timeout = "15m"
}

# -----------------------------------------------------------------------------
# Source 2: build directly on Proxmox VE -> VM template (optional)
# -----------------------------------------------------------------------------
source "proxmox-iso" "rocky10" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_insecure_tls
  node                     = var.proxmox_node

  vm_id                = var.proxmox_vm_id
  vm_name              = local.pve_name
  template_name        = local.pve_name
  template_description = "${var.proxmox_template_description} (${local.timestamp})"
  tags                 = "rocky;rocky10;packer"

  boot_iso {
    type     = "ide"
    iso_file = var.proxmox_iso_file
    unmount  = true
  }

  os         = "l26"
  machine    = "q35"
  bios       = var.firmware == "uefi" ? "ovmf" : "seabios"
  cpu_type   = var.proxmox_cpu_type
  sockets    = var.proxmox_sockets
  cores      = var.cpus
  memory     = var.memory
  qemu_agent = true

  dynamic "efi_config" {
    for_each = var.firmware == "uefi" ? [1] : []
    content {
      efi_storage_pool  = var.proxmox_efi_storage
      efi_type          = "4m"
      pre_enrolled_keys = false
    }
  }

  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = var.disk_size
    storage_pool = var.proxmox_disk_storage
    format       = var.proxmox_disk_format
    io_thread    = true
    discard      = true
    ssd          = true
  }

  network_adapters {
    model    = "virtio"
    bridge   = var.proxmox_bridge
    vlan_tag = var.proxmox_vlan_tag != "" ? var.proxmox_vlan_tag : null
    firewall = false
  }

  serials                 = ["socket"]
  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_cloud_init_storage

  http_content      = { "/ks.cfg" = local.kickstart }
  http_bind_address = var.http_bind_address
  http_port_min     = var.http_port_min
  http_port_max     = var.http_port_max

  boot_wait    = var.boot_wait
  boot_command = local.boot_command

  communicator = "ssh"
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = var.ssh_timeout
}

# -----------------------------------------------------------------------------
# Build: shared provisioning for both sources
# -----------------------------------------------------------------------------
build {
  sources = ["source.qemu.rocky10", "source.proxmox-iso.rocky10"]

  # Upload helper files (nginx config, etc.)
  provisioner "file" {
    source      = "${path.root}/files/"
    destination = "/tmp/packer-files"
  }

  # Base system: repos, update, packages, guest agent, cloud-init
  provisioner "shell" {
    execute_command  = local.sudo_execute
    environment_vars = local.provision_env
    scripts = [
      "${path.root}/scripts/provision/00-base.sh",
      "${path.root}/scripts/provision/10-proxmox-integration.sh",
    ]
  }

  # Optional reboot to boot into the updated kernel
  provisioner "shell" {
    execute_command   = local.sudo_execute
    expect_disconnect = true
    inline            = var.reboot_after_update ? ["systemctl reboot"] : ["echo 'reboot skipped'"]
  }

  # Security hardening + example applications (each script checks its own flag)
  provisioner "shell" {
    pause_before     = var.reboot_after_update ? "60s" : "0s"
    execute_command  = local.sudo_execute
    environment_vars = local.provision_env
    scripts = [
      "${path.root}/scripts/provision/20-security.sh",
      "${path.root}/scripts/provision/30-nginx.sh",
      "${path.root}/scripts/provision/40-docker.sh",
      "${path.root}/scripts/provision/41-podman.sh",
      "${path.root}/scripts/provision/50-postgresql.sh",
      "${path.root}/scripts/provision/60-nodejs.sh",
      "${path.root}/scripts/provision/70-node-exporter.sh",
    ]
  }

  # Your own commands from the variables file
  provisioner "shell" {
    execute_command = local.sudo_execute
    inline          = concat(["echo '==> Running custom_commands'"], var.custom_commands)
  }

  # Generalize the image (must be last)
  provisioner "shell" {
    execute_command  = local.sudo_execute
    environment_vars = local.provision_env
    script           = "${path.root}/scripts/provision/99-cleanup.sh"
  }

  post-processor "checksum" {
    only           = ["qemu.rocky10"]
    checksum_types = ["sha256"]
    output         = "${var.output_directory}/${local.image_name}/${local.image_name}.{{ .ChecksumType }}"
  }

  post-processor "manifest" {
    output     = "${var.output_directory}/manifest.json"
    strip_path = false
    custom_data = {
      image_name = local.image_name
      os_version = var.os_version
      firmware   = var.firmware
    }
  }
}
