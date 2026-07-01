# eCommerce IaC Project

Infrastructure-as-Code deployment of an eCommerce application on a local KVM/QEMU hypervisor, using Terraform to provision virtual machines and Ansible to configure them.

## Architecture

The application runs across 8 VMs on a private NAT network (`192.168.100.0/24`):

| VM | Role | IP | vCPU | RAM |
|----|------|----|------|-----|
| `lb1` | Nginx load balancer | 192.168.100.10 | 1 | 1 GB |
| `web1` | React frontend (Nginx) | 192.168.100.20 | 1 | 1 GB |
| `web2` | React frontend (Nginx) | 192.168.100.21 | 1 | 1 GB |
| `app1` | Django + Gunicorn backend | 192.168.100.30 | 2 | 2 GB |
| `app2` | Django + Gunicorn backend | 192.168.100.31 | 2 | 1 GB |
| `db1` | PostgreSQL database | 192.168.100.40 | 2 | 4 GB |
| `cache1` | Redis cache | 192.168.100.50 | 1 | 512 MB |
| `nfs1` | NFS shared media storage | 192.168.100.60 | 1 | 512 MB |

Traffic flows: client → `lb1` → `web1`/`web2` (static assets) or `app1`/`app2` (API requests) → `db1` / `cache1`. Product images are stored on `nfs1` and mounted by the app servers.

## Stack

- **Frontend**: React + Vite (TypeScript)
- **Backend**: Django + Gunicorn
- **Database**: PostgreSQL with streaming replication
- **Cache**: Redis
- **Shared storage**: NFS
- **Web/proxy**: Nginx
- **Provisioning**: Terraform with the `dmacvicar/libvirt` provider
- **Configuration**: Ansible with community Galaxy roles
- **Base OS**: Ubuntu 22.04 (cloud image)

## Prerequisites

- KVM/QEMU and `libvirt` installed and running on the host
- `terraform` CLI installed
- Python 3 (for the Ansible virtualenv)
- `virsh` and `wget` available

## First-time Setup

Run these once before the first deployment:

```bash
# 1. Install Ansible into a virtualenv and set up the Terraform libvirt provider
make prereqs

# 2. Generate the SSH key used to access VMs
make ssh-key
# Copy the printed public key into terraform/environments/dev/terraform.tfvars
#   ssh_public_key = "ssh-ed25519 AAAA..."

# 3. Download the Ubuntu 22.04 cloud image
make download-image

# 4. Initialise Terraform
make tf-init

# 5. Install Ansible Galaxy roles
make ansible-deps
```

## Starting the Environment

### Full bring-up (first time or after `make clean`)

```bash
# Provision VMs with Terraform
make tf-apply

# Start all VMs in dependency order
make vms-up

# Verify Ansible connectivity
make ping

# Configure all VMs (database → cache → nfs → backend → frontend → load balancer)
make deploy
```

### Resuming an already-provisioned environment

```bash
# Start VMs (they already exist in libvirt)
make vms-up

# (Optional) Re-deploy config if anything changed
make deploy
```

Once up, the application is reachable at `http://192.168.100.10`.

## Shutting Down

### Graceful shutdown (keep VMs, destroy nothing)

```bash
make vms-down
```

### Destroy everything (delete all VMs and disks)

```bash
make clean        # default ENV=dev
# or
make tf-destroy
```

## Partial Re-deployments

Re-run only a specific layer without touching the rest:

```bash
make deploy-backend    # Django app only
make deploy-frontend   # React static files only
make deploy-db         # PostgreSQL config only
make deploy-lb         # Load balancer config only
make deploy-nfs        # NFS server/client only
```

## Environment Management

The `ENV` variable selects the target environment (default: `dev`). A `prod` environment configuration exists under `terraform/environments/prod/` and `ansible/inventories/prod/`.

```bash
make tf-apply ENV=prod
make deploy   ENV=prod
```

## Project Layout

```
.
├── Makefile                        # All top-level commands
├── terraform/
│   ├── environments/
│   │   ├── dev/                    # Dev environment (main.tf, variables, tfvars)
│   │   └── prod/                   # Prod environment
│   └── modules/vm/                 # Reusable VM module (cloud-init, network)
└── ansible/
    ├── ansible.cfg
    ├── requirements.yml            # Galaxy role dependencies
    ├── inventories/
    │   ├── dev/                    # Dev hosts and group_vars
    │   └── prod/
    ├── playbooks/
    │   ├── site.yml                # Master playbook (runs all)
    │   ├── backend.yml
    │   ├── frontend.yml
    │   ├── database.yml
    │   ├── cache.yml
    │   ├── lb.yml
    │   └── nfs.yml
    └── roles/
        ├── django-app/             # Gunicorn service + Nginx backend proxy
        ├── frontend-deploy/        # Nginx static file server
        ├── lb-config/              # Nginx upstream load balancer
        ├── db-replication/         # PostgreSQL streaming replication
        ├── nfs-server/             # NFS export configuration
        ├── nfs-client/             # NFS mount on app servers
        └── geerlingguy.*/          # Community roles: nginx, postgresql, redis, pip, certbot
```

## Useful Commands

```bash
make vms-status     # Show running state of every VM
make ping           # Test Ansible connectivity to all hosts
make help           # List all available make targets
```
