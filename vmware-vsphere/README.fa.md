# کلاستر Kubernetes روی VMware vSphere با Terraform و Ansible

[English](README.md) | **فارسی**

- **Terraform** (`terraform/`): از یک تمپلیت در vSphere، VMهای **مستر** و **ورکر** را کلون می‌کند، IP ثابت و hostname می‌دهد و فایل inventory انسیبل را خودش می‌سازد.
- **Ansible** (`ansible/`): نودها را آماده می‌کند (containerd، kubeadm/kubelet/kubectl، swap، sysctl، فایروال، SELinux)، کلاستر را با `kubeadm` بالا می‌آورد، Calico را نصب و ورکرها را join می‌کند.
  با بیش از یک مستر، **kube-vip** یک IP مجازی (VIP) برای API Server بین مسترها جابه‌جا می‌کند (HA).

```text
vmware-vsphere/
├── terraform/
│   ├── versions.tf              # provider ها (vsphere, local)
│   ├── variables.tf             # تعریف متغیرها
│   ├── main.tf                  # VM ها، فولدر، قوانین anti-affinity، ساخت inventory
│   ├── outputs.tf
│   ├── terraform.tfvars.example # ⭐ این را کپی و ویرایش کنید
│   └── templates/hosts.ini.tftpl
└── ansible/
    ├── ansible.cfg
    ├── requirements.yml         # کالکشن‌های ansible.posix و community.general
    ├── inventory/hosts.ini      # توسط Terraform ساخته می‌شود (نمونه: hosts.ini.example)
    ├── group_vars/all.yml       # ⭐ نسخه Kubernetes، شبکه Pod، VIP، Calico، فایروال
    ├── site.yml                 # نصب کامل کلاستر
    ├── reset.yml                # پاک کردن کامل Kubernetes از نودها
    └── roles/
        ├── common/              # hostname، /etc/hosts، swap، ماژول‌های کرنل، sysctl، SELinux، فایروال
        ├── containerd/          # نصب containerd با SystemdCgroup
        ├── kubernetes/          # نصب kubelet/kubeadm/kubectl از pkgs.k8s.io
        ├── control_plane/       # kubeadm init روی مستر اول، join بقیه مسترها، kube-vip
        ├── cni/                 # Calico (tigera-operator)
        └── worker/              # join ورکرها
```

## ۱. پیش‌نیازها

| مورد | توضیح |
|------|-------|
| Terraform ≥ 1.5 | روی سیستمی که به vCenter دسترسی دارد |
| Ansible ≥ 2.16 | `pip install ansible` (یا ansible-core + `ansible-galaxy collection install -r ansible/requirements.yml`) |
| تمپلیت VM در vSphere | Rocky/Alma/RHEL 9-10 یا Ubuntu 22.04/24.04 با **open-vm-tools** و **cloud-init** (مثلاً تمپلیتی که با Packer همین مخزن ساخته‌اید) |
| کلید SSH | `ssh-keygen -t ed25519` |
| اینترنت روی نودها | برای مخازن Docker، pkgs.k8s.io، registry.k8s.io، ghcr.io و quay.io |

سیستم‌عامل‌های پشتیبانی‌شده در Ansible: خانواده RedHat (Rocky/Alma/RHEL) و Debian (Ubuntu/Debian).

### روش مقداردهی VM (`customization_method`)

| مقدار | نحوه کار | نیاز تمپلیت |
|-------|----------|-------------|
| `cloud-init` (پیش‌فرض) | hostname، IP و کاربر SSH با کلید از طریق `guestinfo` به cloud-init داده می‌شود | cloud-init (دیتاسورس VMware) + open-vm-tools |
| `vmware` | Guest Customization خود vSphere (hostname و IP) | open-vm-tools؛ کاربر و کلید SSH باید از قبل داخل تمپلیت باشد |

> اگر تمپلیت را با Packer می‌سازید، قبل از تبدیل به تمپلیت `cloud-init clean` اجرا شده باشد.

## ۲. ساخت VMها با Terraform

```bash
cd vmware-vsphere/terraform
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars                 # vCenter، دیتاسنتر، کلاستر، دیتااستور، شبکه، تمپلیت، IPها

export TF_VAR_vsphere_password='رمز vCenter'   # رمز را در فایل ننویسید

terraform init
terraform plan
terraform apply
```

تعداد نودها با map های `masters` و `workers` تعیین می‌شود؛ برای افزودن ورکر یک خط اضافه کنید و دوباره `terraform apply` بزنید.
منابع هر نود از `master_defaults` / `worker_defaults` می‌آید و برای هر نود قابل override است:

```hcl
workers = {
  "k8s-worker-01" = { ip = "192.168.10.21" }
  "k8s-worker-02" = { ip = "192.168.10.22", num_cpus = 8, memory = 16384, disk_size = 200 }
}
```

- برای HA از **۳ مستر** (عدد فرد) استفاده کنید.
- با `enable_anti_affinity = true` قانون DRS ساخته می‌شود تا مسترها (و ورکرها) روی هاست‌های ESXi متفاوت باشند.
- `enable_disk_uuid` برای vSphere CSI Driver فعال است.
- خروجی: فایل `ansible/inventory/hosts.ini` به‌صورت خودکار ساخته می‌شود.

## ۳. نصب Kubernetes با Ansible

```bash
cd ../ansible
vi group_vars/all.yml
```

مهم‌ترین متغیرها:

| متغیر | پیش‌فرض | توضیح |
|-------|---------|-------|
| `kubernetes_version` | `1.36` | نسخه مینور Kubernetes |
| `kubernetes_package_version` | `""` | نسخه دقیق (مثلاً `1.36.2`)؛ خالی = آخرین patch |
| `control_plane_vip` | `""` | **با بیش از یک مستر الزامی است**: یک IP آزاد در همان شبکه نودها |
| `pod_network_cidr` | `10.244.0.0/16` | نباید با شبکه نودها هم‌پوشانی داشته باشد |
| `service_cidr` | `10.96.0.0/12` | |
| `calico_version` | `v3.33.0` | |
| `calico_encapsulation` | `VXLANCrossSubnet` | `VXLAN`، `IPIP` یا `None` |
| `firewall_mode` | `open-ports` | باز کردن پورت‌ها در firewalld/ufw، یا `disable` برای خاموش کردن فایروال |
| `selinux_state` | `permissive` | |

اجرا:

```bash
ansible-galaxy collection install -r requirements.yml   # اگر فقط ansible-core دارید
ansible all -m ping                                     # تست اتصال
ansible-playbook site.yml
```

ترتیب کار `site.yml`:
1. آماده‌سازی همه نودها (common → containerd → kubernetes)
2. `kubeadm init` روی مستر اول، سپس join بقیه مسترها **یکی‌یکی**
3. نصب Calico
4. join ورکرها و برچسب `node-role.kubernetes.io/worker`
5. انتظار تا Ready شدن همه نودها و نمایش `kubectl get nodes`

Playbook ایدمپوتنت است: نودهایی که قبلاً join شده‌اند دوباره init/join نمی‌شوند؛ پس برای افزودن نود جدید کافی است بعد از `terraform apply` دوباره `ansible-playbook site.yml` اجرا کنید.

## ۴. دسترسی به کلاستر

فایل kubeconfig در `ansible/artifacts/admin.conf` کپی می‌شود (در git نمی‌رود):

```bash
export KUBECONFIG=$PWD/artifacts/admin.conf
kubectl get nodes -o wide
kubectl get pods -A
```

روی مسترها هم برای root و کاربر SSH در `~/.kube/config` قرار دارد.

## ۵. پاک کردن

```bash
# فقط Kubernetes را از نودها پاک کن (VMها می‌مانند)
ansible-playbook reset.yml -e confirm_reset=yes

# حذف کامل VMها
cd ../terraform && terraform destroy
```

## نکات و عیب‌یابی

- **VIP جواب نمی‌دهد:** kube-vip در حالت ARP کار می‌کند؛ VIP باید در همان subnet نودها و آزاد باشد. روی port group در vSphere گزینه‌های *MAC Address Changes* و *Forged Transmits* نباید Reject باشند (یا از Distributed Switch با تنظیمات مناسب استفاده کنید).
- **VM بدون IP بالا می‌آید:** در حالت `cloud-init` بررسی کنید cloud-init روی تمپلیت نصب است و `cloud-init clean` قبل از تمپلیت شدن اجرا شده؛ لاگ: `/var/log/cloud-init.log`.
- **Terraform روی "waiting for IP" می‌ماند:** open-vm-tools در تمپلیت نصب و فعال باشد.
- **Rocky/RHEL 10:** پردازنده باید x86-64-v3 را پشتیبانی کند (در vSphere، EVC mode حداقل Haswell).
- برای استفاده از دیسک‌های vSphere به‌عنوان PersistentVolume، بعداً **vSphere CSI Driver** را نصب کنید.
