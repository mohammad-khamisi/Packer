# Shortcuts – run `make help`
TERRAFORM ?= terraform

.PHONY: help init fmt validate plan apply destroy

help:
	@echo "make init     - download the vSphere provider"
	@echo "make fmt      - format .tf files"
	@echo "make validate - validate the configuration"
	@echo "make plan     - show what will be created"
	@echo "make apply    - create the VMs"
	@echo "make destroy  - delete the VMs"

init:
	$(TERRAFORM) init

fmt:
	$(TERRAFORM) fmt -recursive

validate: init
	$(TERRAFORM) validate

plan: validate
	$(TERRAFORM) plan -out=vm.tfplan

apply:
	$(TERRAFORM) apply vm.tfplan

destroy:
	$(TERRAFORM) destroy
