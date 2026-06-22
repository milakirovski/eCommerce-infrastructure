# ──────────────────────────────────────────────────────────────────────────────
# eCommerce IaC Makefile
# Usage: make <target>   (e.g. make dev-up, make dev-deploy)
# ──────────────────────────────────────────────────────────────────────────────

ENV       ?= dev
TF_DIR     = terraform/environments/$(ENV)
ANS_DIR    = ansible
INVENTORY  = $(ANS_DIR)/inventories/$(ENV)/hosts.ini
PLAYBOOK   = $(ANS_DIR)/playbooks/site.yml
IMAGE_URL  = https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
IMAGE_FILE = /tmp/ubuntu-22.04-server-cloudimg-amd64.img
SSH_KEY    = ~/.ssh/ecommerce_key

.PHONY: help prereqs ssh-key download-image \
        tf-init tf-plan tf-apply tf-destroy \
        ansible-deps deploy deploy-backend deploy-frontend deploy-db deploy-lb \
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
	@echo "  Ansible (configure VMs):"
	@echo "    make ansible-deps   Download Galaxy roles"
	@echo "    make ping           Verify Ansible can reach all VMs"
	@echo "    make deploy         Run full site.yml playbook"
	@echo "    make deploy-backend Re-deploy only the Django app"
	@echo "    make deploy-frontend Re-deploy only the React frontend"
	@echo ""

# ── Prerequisites ─────────────────────────────────────────────────────────────
prereqs:
	@echo ">>> Installing Ansible..."
	pip3 install --user ansible
	@echo ">>> Installing Terraform libvirt provider (handled by terraform init)"
	@echo ">>> Done. You may need to add ~/.local/bin to your PATH."
	@echo "    Run: export PATH=\$$PATH:~/.local/bin"

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

# ── Ansible ───────────────────────────────────────────────────────────────────
ansible-deps:
	cd $(ANS_DIR) && ansible-galaxy install -r requirements.yml

ping:
	cd $(ANS_DIR) && ansible all -i $(INVENTORY) -m ping

deploy:
	cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) $(PLAYBOOK)

deploy-backend:
	cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) playbooks/backend.yml

deploy-frontend:
	cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) playbooks/frontend.yml

deploy-db:
	cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) playbooks/database.yml

deploy-lb:
	cd $(ANS_DIR) && ansible-playbook -i $(INVENTORY) playbooks/lb.yml

clean:
	@echo ">>> This will DELETE all $(ENV) VMs. Are you sure? Press Ctrl-C to cancel, Enter to continue."
	@read _confirm
	make tf-destroy ENV=$(ENV)
