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

resource "libvirt_pool" "ecommerce_prod" {
  name = "ecommerce-prod"
  type = "dir"

  target = {
    path = var.storage_pool_path
  }
}

resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-22.04-cloudimg.qcow2"
  pool = libvirt_pool.ecommerce_prod.name

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

resource "libvirt_network" "prod" {
  name = "ecommerce-prod"

  forward = {
    mode = "nat"
  }

  domain = {
    name       = "ecommerce.prod"
    local_only = "no"
  }

  ips = [
    {
      family  = "ipv4"
      address = "192.168.200.1"
      netmask = "255.255.255.0"
    }
  ]

  dns = {
    enable = "yes"
  }
}

# ── Production VMs ────────────────────────────────────────────────────────────
# Production: 2 LBs, 3 web, 3 app, 2 DB, 2 cache = 12 VMs total

locals {
  vms = {
    # Load Balancers
    lb1 = { vcpu = 2, memory = 2048, ip = "192.168.200.10", disk = 10737418240 }
    lb2 = { vcpu = 2, memory = 2048, ip = "192.168.200.11", disk = 10737418240 }

    # Frontend (Nginx serving React SPA)
    web1 = { vcpu = 2, memory = 2048, ip = "192.168.200.20", disk = 10737418240 }
    web2 = { vcpu = 2, memory = 2048, ip = "192.168.200.21", disk = 10737418240 }
    web3 = { vcpu = 2, memory = 2048, ip = "192.168.200.22", disk = 10737418240 }

    # Backend (Django + Gunicorn)
    app1 = { vcpu = 4, memory = 4096, ip = "192.168.200.30", disk = 16106127360 }
    app2 = { vcpu = 4, memory = 4096, ip = "192.168.200.31", disk = 16106127360 }
    app3 = { vcpu = 4, memory = 4096, ip = "192.168.200.32", disk = 16106127360 }

    # Database (PostgreSQL primary + replica)
    db1 = { vcpu = 4, memory = 8192, ip = "192.168.200.40", disk = 53687091200 } # 50 GB
    db2 = { vcpu = 4, memory = 8192, ip = "192.168.200.41", disk = 53687091200 }

    # Cache (Redis)
    cache1 = { vcpu = 2, memory = 2048, ip = "192.168.200.50", disk = 10737418240 }
    cache2 = { vcpu = 2, memory = 2048, ip = "192.168.200.51", disk = 10737418240 }
  }
}

module "vms" {
  source   = "../../modules/vm"
  for_each = local.vms

  vm_name          = each.key
  vcpu             = each.value.vcpu
  memory           = each.value.memory
  disk_size        = each.value.disk
  ip_address       = each.value.ip
  gateway          = "192.168.200.1"
  network_name     = libvirt_network.prod.name
  pool_name        = libvirt_pool.ecommerce_prod.name
  base_volume_path = libvirt_volume.ubuntu_base.path
  ssh_public_key   = var.ssh_public_key
}
