<div dir="rtl">

# ترافرم: ساخت VM با Rocky Linux 10.2 روی VMware vSphere

[English](README.md) | **فارسی**

این پوشه با Clone کردن یک Template، یک یا چند ماشین **Rocky Linux 10.2** روی vSphere می‌سازد.
تنظیمات در سه مرحله اعمال می‌شود:

| مرحله | زمان اجرا | روش | متغیرها |
|-------|-----------|-----|---------|
| ۱. ابتدای بوت | هر بار بوت، قبل از بالا آمدن شبکه | cloud-init `bootcmd` | `early_commands` |
| ۲. اولین بوت | یک بار: شبکه، hostname، کاربر، پکیج‌ها و سپس دستورات | cloud-init `runcmd` | `ipv4_*`، `dns_servers`، `packages`، `first_boot_commands` |
| ۳. بعد از ساخت | ترافرم بعد از تمام شدن cloud-init با SSH وصل می‌شود | `scripts/post-create/*.sh` و دستورات (با دسترسی root) | `post_create_commands` |

همهٔ متغیرهای دستورات را می‌توانید برای هر VM جداگانه هم داخل `vms` بنویسید
(`early_commands`، `first_boot_commands`، `post_create_commands`، `extra_packages`). این دستورات بعد از دستورات عمومی اجرا می‌شوند.

## ساختار فایل‌ها

</div>

```text
vmware-vsphere/
├── versions.tf / providers.tf   # نسخهٔ ترافرم، provider و اتصال به vCenter
├── variables.tf                 # همهٔ متغیرها
├── data.tf                      # پیدا کردن datacenter، cluster، datastore، network و template
├── main.tf                      # فولدر و VMها
├── cloud-init.tf                # تنظیمات شبکه، کاربر، پکیج‌ها و دستورات بوت
├── post-create.tf               # مرحلهٔ SSH بعد از ساخت
├── outputs.tf                   # شناسه، IP و دستور ssh هر ماشین
├── terraform.tfvars.example     # ⭐ کپی کنید به terraform.tfvars و ویرایش کنید
└── scripts/
    ├── prepare-template.sh      # یک بار داخل VM راکی ۱۰.۲ (قبل از تبدیل به Template)
    └── post-create/             # اسکریپت‌هایی که به ترتیب نام، بعد از ساخت اجرا می‌شوند
        ├── 10-base.sh           # chrony و firewalld
        ├── 20-network.sh        # نمونه‌های nmcli و تنظیمات sysctl شبکه
        └── 90-summary.sh        # نمایش اطلاعات ماشین
```

<div dir="rtl">

## ۱. آماده‌سازی Template راکی لینوکس ۱۰.۲ (فقط یک بار)

1. راکی لینوکس ۱۰.۲ را روی یک VM در vSphere نصب کنید (در vSphere 8 به بالا، Guest OS را *Rocky Linux (64-bit)* انتخاب کنید).
2. فایل `scripts/prepare-template.sh` را داخل آن کپی و اجرا کنید:

</div>

```bash
sudo bash prepare-template.sh && sudo poweroff
```

<div dir="rtl">

این اسکریپت `open-vm-tools` و `cloud-init` را نصب می‌کند، datasource مخصوص VMware را فعال می‌کند و ماشین را عمومی‌سازی (Generalize) می‌کند.

3. در vCenter گزینهٔ *Convert to Template* را بزنید و نام آن را در متغیر `template` بنویسید.

> ایمیجی که Packer در ریشهٔ همین ریپو برای Proxmox می‌سازد از `qemu-guest-agent` و NoCloud استفاده می‌کند
> و بدون اجرای این اسکریپت برای vSphere مناسب نیست.

## ۲. ساخت ماشین‌ها

</div>

```bash
cd vmware-vsphere
cp terraform.tfvars.example terraform.tfvars   # مقادیر را ویرایش کنید
export TF_VAR_vsphere_password='YourPassword'

terraform init
terraform plan
terraform apply
```

<div dir="rtl">

یا با make: ابتدا `make plan` و سپس `make apply`. برای حذف: `terraform destroy`.

## تعریف ماشین‌ها

</div>

```hcl
vms = {
  "web-01" = {
    cpus = 2, memory_mb = 4096, disk_gb = 40, ipv4_address = "192.168.10.51"
    extra_packages       = ["nginx"]
    post_create_commands = ["systemctl enable --now nginx"]
  }
  "test-01" = {}   # پیش‌فرض: ۲ هسته، ۴ گیگ رم، دیسک ۴۰ گیگ، DHCP
}
```

<div dir="rtl">

اگر `ipv4_address` را ندهید، ماشین از DHCP آدرس می‌گیرد.

## نکات

- مرحلهٔ بعد از ساخت به اتصال SSH از سیستمی که ترافرم روی آن اجرا می‌شود به ماشین‌ها نیاز دارد. کلید خصوصی
  `ssh_private_key_path` باید با یکی از کلیدهای `ssh_authorized_keys` جفت باشد. برای غیرفعال کردن این مرحله: `enable_post_create = false`.
- اگر یکی از اسکریپت‌ها یا `post_create_commands` را تغییر دهید، با `apply` بعدی این مرحله دوباره اجرا می‌شود؛ پس اسکریپت‌ها باید قابل اجرای مجدد باشند.
- تنظیمات cloud-init فقط در اولین بوت اعمال می‌شوند و تغییر آن‌ها روی ماشین‌های موجود اثری ندارد.
- فایل‌های `terraform.tfvars` و `*.tfstate` در gitignore هستند (فایل state اطلاعات حساس دارد).

</div>
