# =============================================================================
#  Rocky Linux 10 kickstart – rendered by Packer (templatefile)
#  All values come from the Packer variables.
# =============================================================================

text
cdrom
eula --agreed
firstboot --disabled
skipx

lang ${locale}
keyboard --vckeymap=${keyboard} --xlayouts='${keyboard}'
timezone ${timezone} --utc

network --bootproto=dhcp --device=link --activate --onboot=on --hostname=${hostname}

%{ if root_password != "" ~}
rootpw --plaintext --allow-ssh ${root_password}
%{ else ~}
rootpw --lock
%{ endif ~}
user --name=${ssh_username} --groups=wheel --plaintext --password=${ssh_password}

selinux --${selinux_mode}
%{ if firewall ~}
firewall --enabled --service=ssh
%{ else ~}
firewall --disabled
%{ endif ~}
services --enabled=sshd,chronyd

# Disk: GPT, platform partitions (biosboot or EFI + /boot) and a single XFS
# root without LVM/swap so cloud-init growpart can extend it on Proxmox.
zerombr
clearpart --all --initlabel --disklabel=gpt
bootloader --timeout=1 --append="console=tty0 console=ttyS0,115200n8 no_timer_check net.ifnames=0"
reqpart --add-boot
part / --fstype=xfs --size=4096 --grow

reboot --eject

%packages --excludedocs
@^minimal-environment
openssh-server
sudo
chrony
-iwl*-firmware
-microcode_ctl
-plymouth
%end

%post --erroronfail --log=/root/ks-post.log
# Passwordless sudo for the Packer build user (removed at the end of the build)
echo "${ssh_username} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${ssh_username}
chmod 0440 /etc/sudoers.d/${ssh_username}

# Make sure Packer can log in with a password during the build
mkdir -p /etc/ssh/sshd_config.d
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/00-packer-build.conf
%end
