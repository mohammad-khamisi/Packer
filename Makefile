# Shortcuts – run `make help`
PACKER ?= packer

.PHONY: help init fmt validate validate-proxmox build build-proxmox clean

help:
	@echo "make init           - download Packer plugins"
	@echo "make fmt            - format HCL files"
	@echo "make validate       - validate the QEMU (qcow2) build"
	@echo "make validate-proxmox - validate the Proxmox build"
	@echo "make build          - build the qcow2 file locally (QEMU/KVM)"
	@echo "make build-proxmox  - build a template directly on Proxmox"
	@echo "make clean          - remove output/ and packer_cache/"

init:
	$(PACKER) init .

fmt:
	$(PACKER) fmt .

validate: init
	$(PACKER) validate -only='qemu.rocky10' .

validate-proxmox: init
	$(PACKER) validate -only='proxmox-iso.rocky10' .

build: validate
	PACKER_LOG=1 PACKER_LOG_PATH=packer-build.log $(PACKER) build -only='qemu.rocky10' .

build-proxmox: validate-proxmox
	PACKER_LOG=1 PACKER_LOG_PATH=packer-build.log $(PACKER) build -only='proxmox-iso.rocky10' .

clean:
	rm -rf output packer_cache packer-build.log
