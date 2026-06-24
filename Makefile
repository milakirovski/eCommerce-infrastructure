# ──────────────────────────────────────────────────────────────────────────────
# eCommerce IaC Makefile
# Usage: make <target>   (e.g. make dev-up, make dev-deploy)
# ──────────────────────────────────────────────────────────────────────────────
SHELL := /bin/bash

ENV       ?= dev
TF_DIR     = terraform/environments/$(ENV)
ANS_DIR    = ansible
INVENTORY  = inventories/$(ENV)/hosts.ini
PLAYBOOK   = playbooks/site.yml
ANSIBLE_VENV = $(HOME)/ansible-venv
ACTIVATE   = . $(ANSIBLE_VENV)/bin/activate &&
IMAGE_URL  = https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
IMAGE_FILE = /tmp/ubuntu-22.04-server-cloudimg-amd64.img
SSH_KEY    = ~/.ssh/ecommerce_key

.PHONY: help prereqs ssh-key download-image \
        tf-init tf-plan tf-apply tf-destroy \
        vms-up vms-down vms-status \
        ansible-deps deploy deploy-backend deploy-frontend deploy-db deploy-lb deploy-nfs \
        ping clean

# ── Help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  eCommerce IaC — available targets"
	@echo "  ENV=$(ENV)  (override with: make deploy ENV=prod)"
	@echo ""
	@echo "  First-time setup:"
	@echo "    make prereqs        Install Ansible and the Terraform libvirt provider"
	@echo "    make ssh-key        Generate SSH key for VM access"
	@echo "    make download-image Download Ubuntu 22.04 cloud image"
	@echo ""
	@echo "  Terraform (create VMs):"
	@echo "    make tf-init        terraform init"
	@echo "    make tf-plan        terraform plan"
	@echo "    make tf-apply       terraform apply  (creates VMs)"
	@echo "    make tf-destroy     terraform destroy (deletes VMs)"
	@echo ""
	@echo "  VM power management:"
	@echo "    make vms-up         Start all VMs (dependency order)"
	@echo "    make vms-down       Shut down all VMs (reverse order)"
	@echo "    make vms-status     Show running state of all VMs"
	@echo ""
	@echo "  Ansible (configure VMs):"
	@echo "    make ansible-deps   Download Galaxy roles"
	@echo "    make ping           Verify Ansible can reach all VMs"
	@echo "    make deploy         Run full site.yml playbook"
	@echo "    make deploy-backend Re-deploy only the Django app"
	@echo "    make deploy-frontend Re-deploy only the React frontend"
	@echo ""

# ── Prerequisites ─────────────────────────────────────────────────────────────
prereqs:
	@echo ">>> Creating Ansible virtualenv at $(ANSIBLE_VENV)..."
	python3 -m venv $(ANSIBLE_VENV)
	$(ACTIVATE) pip install --upgrade pip ansible
	@echo ">>> Installing Terraform libvirt provider (handled by terraform init)"
	@echo ">>> Done."

ssh-key:
	@if [ ! -f $(SSH_KEY) ]; then \
		ssh-keygen -t ed25519 -f $(SSH_KEY) -N "" -C "ecommerce-iac"; \
		echo ">>> Key created: $(SSH_KEY)"; \
		echo ">>> Public key (paste into terraform.tfvars):"; \
		cat $(SSH_KEY).pub; \
	else \
		echo ">>> Key already exists: $(SSH_KEY)"; \
		cat $(SSH_KEY).pub; \
	fi

download-image:
	@if [ ! -f $(IMAGE_FILE) ]; then \
		echo ">>> Downloading Ubuntu 22.04 cloud image..."; \
		wget -O $(IMAGE_FILE) $(IMAGE_URL); \
	else \
		echo ">>> Image already downloaded: $(IMAGE_FILE)"; \
	fi

# ── Terraform ─────────────────────────────────────────────────────────────────
tf-init:
	cd $(TF_DIR) && terraform init

tf-plan:
	cd $(TF_DIR) && terraform plan

tf-apply:
	cd $(TF_DIR) && terraform apply

tf-destroy:
	cd $(TF_DIR) && terraform destroy

# ── VM power management ──────────────────────────────────────────────────────
# Startup:  db → cache → app → web → lb  (dependencies first)
# Shutdown: lb → web → app → cache → db  (reverse order)

VM_START_ORDER = db1 cache1 nfs1 app1 web1 lb1
VM_STOP_ORDER  = lb1 web1 app1 nfs1 cache1 db1

vms-up:
	@for vm in $(VM_START_ORDER); do \
		state=$$(virsh domstate $$vm 2>/dev/null); \
		if [ "$$state" = "running" ]; then \
			echo ">>> $$vm is already running"; \
		else \
			echo ">>> Starting $$vm..."; \
			virsh start $$vm; \
			sleep 3; \
		fi; \
	done
	@echo ">>> All VMs are up."

vms-down:
	@for vm in $(VM_STOP_ORDER); do \
		state=$$(virsh domstate $$vm 2>/dev/null); \
		if [ "$$state" = "running" ]; then \
			echo ">>> Shutting down $$vm..."; \
			virsh shutdown $$vm; \
			sleep 2; \
		else \
			echo ">>> $$vm is already stopped"; \
		fi; \
	done
	@echo ">>> All VMs are down."

vms-status:
	@echo ""
	@echo "  VM                State"
	@echo "  ──────────────────────────"
	@for vm in $(VM_START_ORDER); do \
		state=$$(virsh domstate $$vm 2>/dev/null || echo "not found"); \
		printf "  %-16s  %s\n" "$$vm" "$$state"; \
	done
	@echo ""

# ── Ansible ───────────────────────────────────────────────────────────────────
ansible-deps:
	$(ACTIVATE) cd $(ANS_DIR) && ansible-galaxy install -r requirements.yml

ping:
	$(ACTIVATE) cd $(ANS_DIR) && ansible all -i $(INVENTORY) -m ping

deploy:
	$(ACTIVATE) cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) $(PLAYBOOK)

deploy-backend:
	$(ACTIVATE) cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) playbooks/backend.yml

deploy-frontend:
	$(ACTIVATE) cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) playbooks/frontend.yml

deploy-db:
	$(ACTIVATE) cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) playbooks/database.yml

deploy-lb:
	$(ACTIVATE) cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) playbooks/lb.yml

deploy-nfs:
	$(ACTIVATE) cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) playbooks/nfs.yml

clean:
	@echo ">>> This will DELETE all $(ENV) VMs. Are you sure? Press Ctrl-C to cancel, Enter to continue."
	@read _confirm
	make tf-destroy ENV=$(ENV)
