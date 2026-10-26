# =============================================================================
#  فایل متغیرها – همه تنظیمات بیلد از اینجا قابل تغییر است
#  این فایل به‌صورت خودکار توسط Packer خوانده می‌شود (*.auto.pkrvars.hcl)
#  رمزها را بهتر است در secrets.auto.pkrvars.hcl بگذارید (در git ثبت نمی‌شود)
# =============================================================================

# -----------------------------------------------------------------------------
# سیستم‌عامل و ISO
# -----------------------------------------------------------------------------
os_version = "10.2"                                      # نسخه Rocky Linux
os_arch    = "x86_64"                                    # معماری
iso_flavor = "minimal"                                   # minimal | dvd1 | boot
iso_mirror = "https://download.rockylinux.org/pub/rocky" # میرور دانلود

# اگر ISO را از قبل دانلود کرده‌اید مسیرش را بدهید (خالی = دانلود از میرور)
# iso_url = "file:///home/user/iso/Rocky-10.2-x86_64-minimal.iso"
iso_url = ""

# چک‌سام ISO؛ خالی = خواندن خودکار از فایل CHECKSUM میرور
# iso_checksum = "sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
iso_checksum = ""

# -----------------------------------------------------------------------------
# نام و مسیر خروجی
# -----------------------------------------------------------------------------
image_name             = "rocky"  # نتیجه: rocky-10.2-x86_64-YYYYMMDD-hhmm.qcow2
image_append_timestamp = true     # افزودن تاریخ و ساعت به نام ایمیج
output_directory       = "output" # پوشه خروجی

# -----------------------------------------------------------------------------
# سخت‌افزار ماشین بیلد (هر دو builder)
# -----------------------------------------------------------------------------
cpus      = 2
memory    = 4096   # MB – نصب‌کننده حداقل 2048 لازم دارد
disk_size = "20G"  # بعداً در Proxmox قابل بزرگ‌کردن است (growpart خودکار)
firmware  = "bios" # bios | uefi – باید با تنظیم VM در Proxmox یکی باشد

# -----------------------------------------------------------------------------
# تنظیمات QEMU (ساخت فایل qcow2)
# -----------------------------------------------------------------------------
qemu_binary           = "qemu-system-x86_64" # روی خود Proxmox هم کار می‌کند
qemu_accelerator      = "kvm"                # kvm | tcg (بدون KVM بسیار کند)
qemu_cpu_model        = "host"               # Rocky 10 حداقل x86-64-v3 می‌خواهد
qemu_machine_type     = "q35"
qemu_disk_interface   = "virtio-scsi"
qemu_disk_compression = true
qemu_ovmf_code        = "/usr/share/OVMF/OVMF_CODE_4M.fd" # فقط برای uefi
qemu_ovmf_vars        = "/usr/share/OVMF/OVMF_VARS_4M.fd" # فقط برای uefi
headless              = true                              # false = نمایش پنجره QEMU
vnc_bind_address      = "127.0.0.1"                       # 0.0.0.0 برای دیدن نصب از راه دور با VNC

# -----------------------------------------------------------------------------
# بوت و کیک‌استارت
# -----------------------------------------------------------------------------
boot_wait         = "10s"
boot_command      = [] # خالی = دستور پیش‌فرض GRUB (برای BIOS و UEFI)
http_bind_address = "0.0.0.0"
http_port_min     = 8100 # برای بیلد روی Proxmox این پورت‌ها را در فایروال باز کنید
http_port_max     = 8150
http_ip_override  = "" # IP سیستمی که Packer روی آن اجرا می‌شود (اگر تشخیص خودکار اشتباه بود)

# -----------------------------------------------------------------------------
# تنظیمات سیستم‌عامل
# -----------------------------------------------------------------------------
hostname = "rocky10-template"
locale   = "en_US.UTF-8"
keyboard = "us"
timezone = "Asia/Tehran"

# رمز root؛ خالی = حساب root قفل (توصیه می‌شود)
root_password = ""

# کاربر موقت بیلد (Packer با این کاربر SSH می‌کند) – root نگذارید
ssh_username      = "packer"
ssh_password      = "Packer@Build2026" # بدون فاصله و کوتیشن
ssh_timeout       = "45m"
remove_build_user = true # حذف کاربر بیلد در انتهای کار

# -----------------------------------------------------------------------------
# پکیج‌ها و آپدیت
# -----------------------------------------------------------------------------
dnf_update          = true
reboot_after_update = false # ریبوت بعد از آپدیت (کرنل جدید)
enable_epel         = true  # فعال‌سازی EPEL و CRB

# پکیج‌های پایه (برای Proxmox لازم‌اند: qemu-guest-agent و cloud-init)
base_packages = [
  "qemu-guest-agent",
  "cloud-init",
  "cloud-utils-growpart",
  "vim-enhanced",
  "curl",
  "wget",
  "tar",
  "unzip",
  "bash-completion",
  "chrony",
  "rsync",
  "lsof",
  "tmux",
]

# پکیج‌های دلخواه شما
extra_packages = [
  "git",
  "htop",
  "net-tools",
  "bind-utils",
  "jq",
]

# دستورات دلخواه که در انتها با دسترسی root اجرا می‌شوند
custom_commands = [
  "echo 'Built with Packer' > /etc/motd.d/packer",
  # "dnf -y install redis && systemctl enable redis",
  # "useradd -m -G wheel deploy",
]

# -----------------------------------------------------------------------------
# امنیت
# -----------------------------------------------------------------------------
selinux_mode                = "enforcing" # enforcing | permissive | disabled
firewall_enabled            = true
firewall_services           = []    # مثال: ["cockpit", "dns"]
firewall_ports              = []    # مثال: ["8080/tcp", "3000/tcp"]
ssh_permit_root_login       = "no"  # no | prohibit-password | yes
ssh_password_authentication = false # false = فقط ورود با کلید SSH
install_fail2ban            = false

# -----------------------------------------------------------------------------
# نرم‌افزارهای نمونه (true = نصب شود)
# -----------------------------------------------------------------------------
install_nginx     = true # وب‌سرور Nginx + باز شدن http/https
nginx_server_name = "_"  # مثال: "example.com www.example.com"

install_docker = false # Docker CE از ریپوی رسمی
docker_users   = []    # کاربرانی که به گروه docker اضافه شوند

install_podman = false # Podman (موتور کانتینر بومی Rocky)

install_postgresql       = false # PostgreSQL
postgresql_open_firewall = false # باز کردن پورت 5432

install_nodejs = false # Node.js و npm

install_node_exporter = false # Prometheus node_exporter روی پورت 9100
node_exporter_version = "1.9.1"

# -----------------------------------------------------------------------------
# پاک‌سازی
# -----------------------------------------------------------------------------
zero_free_space = false # پر کردن فضای خالی با صفر (فایل کوچکتر، بیلد کندتر)

# -----------------------------------------------------------------------------
# بیلد مستقیم روی Proxmox (اختیاری: packer build -only='proxmox-iso.rocky10' .)
# توکن را در secrets.auto.pkrvars.hcl بگذارید
# -----------------------------------------------------------------------------
proxmox_url                  = "https://192.168.1.10:8006/api2/json"
proxmox_username             = "packer@pve!packer" # Token ID
proxmox_insecure_tls         = true
proxmox_node                 = "pve"
proxmox_vm_id                = 9000
proxmox_iso_file             = "local:iso/Rocky-10.2-x86_64-minimal.iso"
proxmox_cpu_type             = "host" # host یا x86-64-v3
proxmox_sockets              = 1
proxmox_disk_storage         = "local-lvm"
proxmox_disk_format          = "raw" # raw برای lvm/zfs/ceph ، qcow2 برای storage از نوع directory
proxmox_efi_storage          = "local-lvm"
proxmox_cloud_init_storage   = "local-lvm"
proxmox_bridge               = "vmbr0"
proxmox_vlan_tag             = ""
proxmox_template_description = "Rocky Linux 10 template built with Packer"
