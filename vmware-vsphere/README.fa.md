<div dir="rtl">

# ترافرم: ساخت VM روی VMware vSphere

[English](README.md) | **فارسی**

این پوشه با **Clone کردن یک Template** (مثلاً همان Template راکی لینوکسی که با Packer در همین ریپو ساخته می‌شود)
یک یا چند ماشین مجازی روی vSphere می‌سازد و تنظیمات hostname، IP ثابت یا DHCP، DNS و منطقهٔ زمانی را
از طریق Guest Customization اعمال می‌کند.

## ساختار فایل‌ها

</div>

```text
vmware-vsphere/
├── versions.tf               # نسخهٔ ترافرم و provider
├── providers.tf              # اتصال به vCenter
├── variables.tf              # تعریف همهٔ متغیرها
├── data.tf                   # پیدا کردن datacenter، cluster، datastore، network و template
├── main.tf                   # ساخت فولدر و VMها
├── outputs.tf                # شناسه و IP ماشین‌ها
├── terraform.tfvars.example  # ⭐ کپی کنید به terraform.tfvars و ویرایش کنید
└── Makefile                  # میانبر دستورات
```

<div dir="rtl">

## پیش‌نیازها

- ترافرم نسخهٔ `1.5` یا بالاتر
- دسترسی به vCenter (روی ESXi تنها، Clone پشتیبانی نمی‌شود)
- یک Template که **VMware Tools / open-vm-tools** روی آن نصب باشد
  (برای Customization و گزارش IP لازم است؛ در لینوکس نصب `perl` هم توصیه می‌شود)

## نحوهٔ اجرا

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

یا با make: ابتدا `make plan` و سپس `make apply`.

## تعریف ماشین‌ها

هر آیتم در `vms` یک VM است؛ کلید آن هم نام VM و هم hostname است. همهٔ فیلدها اختیاری‌اند:

</div>

```hcl
vms = {
  "web-01"  = { cpus = 2, memory_mb = 4096, disk_gb = 40, ipv4_address = "192.168.10.51" }
  "db-01"   = { cpus = 4, memory_mb = 8192, extra_disks_gb = [100], ipv4_address = "192.168.10.52" }
  "test-01" = {}   # پیش‌فرض: 2 هسته، 4 گیگ رم، دیسک 40 گیگ، DHCP
}
```

<div dir="rtl">

اگر `ipv4_address` را ندهید، ماشین از DHCP آدرس می‌گیرد. با اضافه یا حذف کردن یک آیتم و اجرای
`terraform apply` فقط همان ماشین ساخته یا حذف می‌شود.

## حذف ماشین‌ها

</div>

```bash
terraform destroy
```

<div dir="rtl">

## نکات

- فایل‌های `terraform.tfvars` و `*.tfstate` در گیت نادیده گرفته می‌شوند؛ فایل state اطلاعات حساس دارد،
  برای کار تیمی آن را در یک Remote Backend نگه دارید.
- دیسک سیستم‌عامل هیچ‌وقت کوچک‌تر از دیسک Template نمی‌شود.
- تغییر Template باعث ساخت مجدد ماشین‌های موجود نمی‌شود (`ignore_changes`).

</div>
