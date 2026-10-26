# ساخت ایمیج Rocky Linux 10.2 با Packer برای Proxmox VE

<div dir="rtl">

این مخزن یک ایمیج **Rocky Linux 10.2** با **HashiCorp Packer** می‌سازد که آماده استفاده در **Proxmox VE** است
(دارای `qemu-guest-agent` و `cloud-init`، و بزرگ‌شدن خودکار دیسک).

دو روش ساخت وجود دارد (هر دو از یک کیک‌استارت و یک مجموعه اسکریپت استفاده می‌کنند):

| روش | Source | خروجی | کاربرد |
|-----|--------|-------|--------|
| **A (اصلی)** | `qemu.rocky10` | فایل `qcow2` | روی هر لینوکسی با KVM می‌سازید و بعداً فایل را در Proxmox ایمپورت می‌کنید |
| B (اختیاری) | `proxmox-iso.rocky10` | Template داخل Proxmox | Packer مستقیماً از طریق API روی Proxmox می‌سازد |

---

## ۱. ساختار فایل‌ها

```text
.
├── plugins.pkr.hcl              # پلاگین‌های مورد نیاز Packer (qemu و proxmox)
├── variables.pkr.hcl            # تعریف همه متغیرها (نوع، توضیح، مقدار پیش‌فرض)
├── rocky10.auto.pkrvars.hcl     # ⭐ فایل متغیرها – همه تنظیمات را اینجا تغییر دهید
├── secrets.auto.pkrvars.hcl.example  # نمونه فایل رمزها (کپی کنید، push نمی‌شود)
├── rocky10.pkr.hcl              # source ها (qemu / proxmox-iso) و build
├── http/
│   └── ks.cfg.pkrtpl.hcl        # کیک‌استارت (نصب خودکار) – مقادیر از متغیرها پر می‌شود
├── scripts/
│   ├── provision/               # اسکریپت‌هایی که داخل ایمیج اجرا می‌شوند (به ترتیب)
│   │   ├── 00-base.sh           # ریپوها، آپدیت، پکیج‌های پایه و دلخواه، تایم‌زون
│   │   ├── 10-proxmox-integration.sh  # qemu-guest-agent، cloud-init، کنسول سریال
│   │   ├── 20-security.sh       # SELinux، firewalld، سخت‌سازی SSH، fail2ban
│   │   ├── 30-nginx.sh          # مثال: Nginx
│   │   ├── 40-docker.sh         # مثال: Docker CE
│   │   ├── 41-podman.sh         # مثال: Podman
│   │   ├── 50-postgresql.sh     # مثال: PostgreSQL
│   │   ├── 60-nodejs.sh         # مثال: Node.js
│   │   ├── 70-node-exporter.sh  # مثال: Prometheus node_exporter
│   │   └── 99-cleanup.sh        # عمومی‌سازی ایمیج (machine-id، کلیدهای SSH، لاگ‌ها...)
│   └── proxmox/
│       └── import-to-proxmox.sh # ایمپورت qcow2 در Proxmox و تبدیل به Template
├── files/nginx/                 # فایل‌های کانفیگ نمونه که داخل ایمیج کپی می‌شوند
└── Makefile                     # میانبر دستورات
```

---

## ۲. پیش‌نیازها (روش A)

یک سیستم لینوکسی با پشتیبانی **KVM** (فیزیکی، یا VM با nested virtualization، یا **خود سرور Proxmox**).

> ⚠️ Rocky Linux 10 فقط روی پردازنده‌های **x86-64-v3** (Haswell به بعد) اجرا می‌شود.
> به همین دلیل CPU مدل `host` استفاده می‌شود.

### Ubuntu / Debian / Proxmox

```bash
# Packer
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y packer

# QEMU/KVM و OVMF (برای UEFI) – روی Proxmox از قبل نصب است
sudo apt install -y qemu-system-x86 qemu-utils ovmf make git

# بررسی KVM
ls -l /dev/kvm && grep -c -E 'vmx|svm' /proc/cpuinfo
```

### Rocky / Alma / Fedora

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install -y packer qemu-kvm qemu-img edk2-ovmf make git
```

و در فایل متغیرها این دو را تنظیم کنید:

```hcl
qemu_binary    = "/usr/libexec/qemu-kvm"
qemu_ovmf_code = "/usr/share/edk2/ovmf/OVMF_CODE.fd"   # فقط برای uefi
qemu_ovmf_vars = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
```

> 💡 اگر دسترسی به `releases.hashicorp.com` یا GitHub مسدود است، باینری Packer و پلاگین‌ها را دستی دانلود و با
> `packer plugins install --path <file> github.com/hashicorp/qemu` نصب کنید.

---

## ۳. ترتیب اجرای دستورات (روش A – ساخت فایل qcow2)

### گام ۱: دریافت مخزن

```bash
git clone https://github.com/mohammad-khamisi/Packer.git
cd Packer
```

### گام ۲: تنظیم متغیرها

فایل `rocky10.auto.pkrvars.hcl` را باز کنید و هر چیزی را که می‌خواهید تغییر دهید
(نسخه، منابع سخت‌افزاری، تایم‌زون، پکیج‌ها، نرم‌افزارهای نمونه و...).

```bash
nano rocky10.auto.pkrvars.hcl
```

رمزها را در فایل جداگانه بگذارید (در git ثبت نمی‌شود):

```bash
cp secrets.auto.pkrvars.hcl.example secrets.auto.pkrvars.hcl
nano secrets.auto.pkrvars.hcl
```

### گام ۳: نصب پلاگین‌ها

```bash
packer init .
```

### گام ۴: فرمت و اعتبارسنجی

```bash
packer fmt .
packer validate -only='qemu.rocky10' .
```

### گام ۵: ساخت ایمیج

```bash
packer build -only='qemu.rocky10' .

# یا با لاگ کامل:
PACKER_LOG=1 PACKER_LOG_PATH=packer-build.log packer build -only='qemu.rocky10' .

# یا با Makefile (همه گام‌های ۳ تا ۵):
make build
```

مدت زمان: حدود ۱۵ تا ۳۰ دقیقه (بسته به اینترنت و سخت‌افزار).
برای دیدن روند نصب، آدرس VNC که Packer چاپ می‌کند (مثلاً `127.0.0.1:5947`) را با یک VNC Viewer باز کنید.

خروجی:

```text
output/rocky-10.2-x86_64-20261026-1200/
├── rocky-10.2-x86_64-20261026-1200.qcow2
└── rocky-10.2-x86_64-20261026-1200.sha256
output/manifest.json
```

### گام ۶: انتقال فایل به Proxmox

```bash
scp output/rocky-10.2-x86_64-*/rocky-10.2-x86_64-*.qcow2 root@PROXMOX_IP:/root/
scp scripts/proxmox/import-to-proxmox.sh root@PROXMOX_IP:/root/
```

### گام ۷: ساخت Template در Proxmox (روی سرور Proxmox)

**روش خودکار (اسکریپت):**

```bash
ssh root@PROXMOX_IP
chmod +x import-to-proxmox.sh

VMID=9000 NAME=rocky-10-template STORAGE=local-lvm BRIDGE=vmbr0 \
CI_USER=rocky CI_SSHKEY=/root/.ssh/id_rsa.pub \
  ./import-to-proxmox.sh /root/rocky-10.2-x86_64-20261026-1200.qcow2
```

همه تنظیمات اسکریپت (VMID، STORAGE، CORES، MEMORY، FIRMWARE، DISK_SIZE، CI_*، VLAN_TAG ...) در ابتدای
فایل `scripts/proxmox/import-to-proxmox.sh` با توضیح آمده است.

**روش دستی (معادل اسکریپت):**

```bash
qm create 9000 --name rocky-10-template --ostype l26 --machine q35 \
  --cpu host --cores 2 --memory 2048 --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single --serial0 socket --vga serial0 --agent enabled=1

qm disk import 9000 /root/rocky-10.2-x86_64-20261026-1200.qcow2 local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0,discard=on,iothread=1,ssd=1
qm set 9000 --boot order=scsi0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --ciuser rocky --sshkeys /root/.ssh/id_rsa.pub --ipconfig0 ip=dhcp
qm template 9000
```

> اگر ایمیج را با `firmware = "uefi"` ساخته‌اید اضافه کنید:
> `qm set 9000 --bios ovmf --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0`
> (در Proxmox 7 به جای `qm disk import` از `qm importdisk` استفاده کنید.)

### گام ۸: ساخت VM از Template

```bash
qm clone 9000 101 --name web-01 --full
qm set 101 --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1 --nameserver 1.1.1.1
qm disk resize 101 scsi0 +20G      # اختیاری – پارتیشن root خودکار بزرگ می‌شود
qm start 101

ssh rocky@192.168.1.50
```

یا از رابط وب: روی Template راست‌کلیک ← **Clone** ← تب **Cloud-Init** ← User / Password / SSH Key / IP ← **Start**.

---

## ۴. روش B – ساخت مستقیم روی Proxmox (اختیاری)

### گام ۱: ساخت کاربر و توکن API (روی Proxmox)

```bash
pveum user add packer@pve
pveum acl modify / --users packer@pve --roles PVEVMAdmin,PVEDatastoreAdmin,PVESDNUser
pveum user token add packer@pve packer --privsep 0
# مقدار "value" خروجی را در secrets.auto.pkrvars.hcl → proxmox_token بگذارید
```

### گام ۲: آپلود ISO روی Proxmox

```bash
wget -P /var/lib/vz/template/iso \
  https://download.rockylinux.org/pub/rocky/10.2/isos/x86_64/Rocky-10.2-x86_64-minimal.iso
```

### گام ۳: تنظیم متغیرهای `proxmox_*` در `rocky10.auto.pkrvars.hcl` و اجرا

```bash
packer init .
packer validate -only='proxmox-iso.rocky10' .
packer build   -only='proxmox-iso.rocky10' .
# یا: make build-proxmox
```

> ⚠️ VM روی Proxmox فایل کیک‌استارت را از سرور HTTP خود Packer دریافت می‌کند؛ پس سیستمی که Packer روی آن
> اجرا می‌شود باید از شبکه VM قابل دسترس باشد و پورت‌های `http_port_min` تا `http_port_max` (پیش‌فرض 8100-8150)
> در فایروال آن باز باشد. اگر IP اشتباه تشخیص داده شد، `http_ip_override` را تنظیم کنید.

---

## ۵. مثال‌ها – تغییر تنظیمات

همه تنظیمات در `rocky10.auto.pkrvars.hcl` هستند. می‌توانید هر متغیر را موقتاً از خط فرمان هم عوض کنید
(خط فرمان بر فایل اولویت دارد):

```bash
# نصب Nginx + Docker + node_exporter
packer build -only='qemu.rocky10' \
  -var install_nginx=true -var install_docker=true -var install_node_exporter=true .

# دیسک ۴۰ گیگ، ۴ هسته، UEFI
packer build -only='qemu.rocky10' -var disk_size=40G -var cpus=4 -var firmware=uefi .

# استفاده از ISO دانلود شده
packer build -only='qemu.rocky10' \
  -var iso_url=file:///data/iso/Rocky-10.2-x86_64-minimal.iso \
  -var iso_checksum=sha256:<hash> .

# با متغیر محیطی (مناسب برای رمزها)
export PKR_VAR_ssh_password='S3cure-Pass'
```

### نمونه‌های داخل فایل متغیرها

```hcl
# وب‌سرور
install_nginx     = true
nginx_server_name = "example.com www.example.com"

# کانتینر
install_docker = true
docker_users   = []

# دیتابیس
install_postgresql       = true
postgresql_open_firewall = true

# مانیتورینگ
install_node_exporter = true

# پکیج‌ها و پورت‌های دلخواه
extra_packages = ["git", "htop", "nmap", "redis"]
firewall_ports = ["8080/tcp", "6379/tcp"]

# دستورات دلخواه
custom_commands = [
  "systemctl enable redis",
  "echo 'vm.swappiness=10' > /etc/sysctl.d/99-swap.conf",
]
```

### افزودن نرم‌افزار جدید (مثلاً Redis به‌صورت اسکریپت)

1. فایل `scripts/provision/80-redis.sh` را با الگوی اسکریپت‌های موجود بسازید.
2. متغیر `install_redis` را در `variables.pkr.hcl` تعریف و در `rocky10.auto.pkrvars.hcl` مقداردهی کنید.
3. `"INSTALL_REDIS=${var.install_redis}"` را به `provision_env` در `rocky10.pkr.hcl` اضافه کنید.
4. مسیر اسکریپت را به لیست `scripts` در بلوک `build` اضافه کنید.

---

## ۶. فهرست متغیرهای مهم

| متغیر | پیش‌فرض | توضیح |
|-------|---------|-------|
| `os_version` | `10.2` | نسخه Rocky |
| `iso_flavor` | `minimal` | `minimal` / `dvd1` / `boot` |
| `iso_url` / `iso_checksum` | خالی | خالی = خودکار از میرور رسمی |
| `cpus` / `memory` / `disk_size` | `2` / `4096` / `20G` | منابع ماشین بیلد |
| `firmware` | `bios` | `bios` یا `uefi` (باید با VM در Proxmox یکی باشد) |
| `qemu_accelerator` / `qemu_cpu_model` | `kvm` / `host` | تنظیمات QEMU |
| `timezone` / `locale` / `keyboard` | `Asia/Tehran` / `en_US.UTF-8` / `us` | تنظیمات سیستم |
| `ssh_username` / `ssh_password` | `packer` / ... | کاربر موقت بیلد |
| `remove_build_user` | `true` | حذف کاربر بیلد در پایان |
| `root_password` | خالی | خالی = root قفل |
| `dnf_update` / `enable_epel` | `true` / `true` | آپدیت و EPEL |
| `base_packages` / `extra_packages` | لیست | پکیج‌ها |
| `selinux_mode` | `enforcing` | حالت SELinux |
| `firewall_enabled` / `firewall_services` / `firewall_ports` | `true` / `[]` / `[]` | فایروال |
| `ssh_permit_root_login` / `ssh_password_authentication` | `no` / `false` | سخت‌سازی SSH |
| `install_nginx` | `true` | Nginx |
| `install_docker` / `install_podman` | `false` | کانتینر |
| `install_postgresql` / `install_nodejs` | `false` | دیتابیس / Node.js |
| `install_node_exporter` / `install_fail2ban` | `false` | مانیتورینگ / امنیت |
| `custom_commands` | `[]` | دستورات دلخواه |
| `zero_free_space` | `false` | کوچکتر کردن qcow2 |
| `proxmox_*` | ... | فقط برای روش B |

توضیح کامل هر متغیر در `variables.pkr.hcl` آمده است.

---

## ۷. ویژگی‌های ایمیج نهایی

- پارتیشن‌بندی GPT، یک پارتیشن root با XFS بدون LVM/swap ← با بزرگ کردن دیسک در Proxmox، root خودکار بزرگ می‌شود
- `qemu-guest-agent` (نمایش IP در Proxmox، shutdown صحیح، fstrim)
- `cloud-init` با datasource های `NoCloud` و `ConfigDrive` (تب Cloud-Init در Proxmox)
- کنسول سریال `ttyS0` (کار با `--serial0 socket --vga serial0`)
- نام کارت شبکه ثابت `eth0` (`net.ifnames=0`)
- SELinux فعال، firewalld فعال، ورود root و ورود با رمز از طریق SSH غیرفعال (قابل تغییر)
- عمومی‌سازی کامل: machine-id، کلیدهای SSH، hostname، لاگ‌ها، کانکشن‌های شبکه و وضعیت cloud-init پاک می‌شوند

> 🔑 چون ورود با رمز از طریق SSH به‌صورت پیش‌فرض غیرفعال است، در تب Cloud-Init کلید SSH بدهید؛
> یا `ssh_password_authentication = true` بگذارید.

---

## ۸. عیب‌یابی

| مشکل | راه‌حل |
|------|--------|
| `Fatal glibc error: CPU does not support x86-64-v3` | CPU را `host` یا `x86-64-v3` بگذارید (در Packer و در Proxmox) |
| `Could not access KVM kernel module` | KVM فعال نیست؛ virtualization را در BIOS یا nested را روی هایپروایزر فعال کنید |
| Packer در `Waiting for SSH` می‌ماند | با VNC صفحه را ببینید؛ اگر نصب‌کننده به ks.cfg نرسیده، فایروال پورت‌های 8100-8150 یا `http_ip_override` را بررسی کنید |
| منوی GRUB درست ویرایش نمی‌شود | `boot_wait` را بیشتر کنید (مثلاً `20s`) یا `boot_command` را در فایل متغیرها override کنید |
| خطای checksum | `iso_checksum` را دستی با مقدار فایل `CHECKSUM` میرور تنظیم کنید |
| نسخه 10.2 در میرور نیست | نسخه‌های قدیمی به `https://dl.rockylinux.org/vault/rocky` منتقل می‌شوند؛ `iso_mirror` را تغییر دهید |
| VM در Proxmox بوت نمی‌شود | `firmware` بیلد با BIOS/UEFI در VM یکی باشد و `boot order=scsi0` تنظیم شده باشد |
| `output directory already exists` | `make clean` یا `packer build -force ...` |

لاگ کامل: `PACKER_LOG=1 packer build ...` — توقف در خطا برای بررسی: `packer build -on-error=ask ...`

</div>
