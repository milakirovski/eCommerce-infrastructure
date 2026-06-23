terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

# ── Storage ──────────────────────────────────────────────────────────────────

resource "libvirt_pool" "ecommerce_dev" {
  name = "ecommerce-dev"
  type = "dir"

  target = {
    path = var.storage_pool_path
  }
}

# Base Ubuntu 22.04 cloud image — all VM disks are backed by this
resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-22.04-cloudimg.qcow2"
  pool = libvirt_pool.ecommerce_dev.name

  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = var.ubuntu_image_url
    }
  }
}

# ── Network ───────────────────────────────────────────────────────────────────
# NAT network: VMs can reach the internet but are isolated from your LAN.
# Subnet: 192.168.100.0/24, gateway: 192.168.100.1 (managed by libvirt)

resource "libvirt_network" "dev" {
  name = "ecommerce-dev"

  forward = {
    mode = "nat"
  }

  domain = {
    name       = "ecommerce.dev"
    local_only = "no"
  }

  ips = [
    {
      family  = "ipv4"
      address = "192.168.100.1"
      netmask = "255.255.255.0"
    }
  ]

  dns = {
    enable = "yes"
  }
}

# ── VM definitions ────────────────────────────────────────────────────────────
# Dev environment: one VM per role (minimum footprint for testing)

locals {
  vms = {
    lb1 = {
      vcpu   = 1
      memory = 1024        # 1 GB
      ip     = "192.168.100.10"
      disk   = 6442450944  # 6 GB
    }
    web1 = {
      vcpu   = 1
      memory = 1024
      ip     = "192.168.100.20"
      disk   = 6442450944  # 6 GB
    }
    app1 = {
      vcpu   = 2
      memory = 2048        # 2 GB — Django + Gunicorn needs more RAM
      ip     = "192.168.100.30"
      disk   = 8589934592  # 8 GB
    }
    db1 = {
      vcpu   = 2
      memory = 4096        # 4 GB — PostgreSQL benefits from more RAM
      ip     = "192.168.100.40"
      disk   = 12884901888 # 12 GB
    }
    cache1 = {
      vcpu   = 1
      memory = 512         # 512 MB — Redis is lightweight
      ip     = "192.168.100.50"
      disk   = 5368709120  # 5 GB
    }
  }
}

# ── Create VMs using the shared module ───────────────────────────────────────

module "vms" {
  source   = "../../modules/vm"
  for_each = local.vms

  vm_name          = each.key
  vcpu             = each.value.vcpu
  memory           = each.value.memory
  disk_size        = each.value.disk
  ip_address       = each.value.ip
  gateway          = "192.168.100.1"
  network_name     = libvirt_network.dev.name
  pool_name        = libvirt_pool.ecommerce_dev.name
  base_volume_path = libvirt_volume.ubuntu_base.path
  ssh_public_key   = var.ssh_public_key
}
