terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }
}

# ── VM disk — backed by the base Ubuntu cloud image ──────────────────────────

resource "libvirt_volume" "disk" {
  name = "${var.vm_name}-disk.qcow2"
  pool = var.pool_name

  capacity      = var.disk_size
  capacity_unit = "bytes"

  backing_store = {
    path = var.base_volume_path
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

# ── Cloud-init ISO — hostname, SSH key, static IP ────────────────────────────

resource "libvirt_cloudinit_disk" "cloud_init" {
  name = "${var.vm_name}-cloud-init"

  meta_data = yamlencode({
    "instance-id"    = var.vm_name
    "local-hostname" = var.vm_name
  })

  user_data = templatefile("${path.module}/cloud_init/user_data.tpl", {
    hostname       = var.vm_name
    ssh_public_key = var.ssh_public_key
  })

  network_config = templatefile("${path.module}/cloud_init/network_config.tpl", {
    ip_address  = var.ip_address
    gateway     = var.gateway
    dns_servers = var.dns_servers
  })
}

# Upload cloud-init ISO into the storage pool as a volume
resource "libvirt_volume" "cloudinit" {
  name = "${var.vm_name}-cloudinit.iso"
  pool = var.pool_name

  target = {
    format = {
      type = "raw"
    }
  }

  create = {
    content = {
      url = libvirt_cloudinit_disk.cloud_init.path
    }
  }
}

# ── The virtual machine ──────────────────────────────────────────────────────

resource "libvirt_domain" "vm" {
  name    = var.vm_name
  type    = "kvm"
  vcpu    = var.vcpu
  memory  = var.memory * 1024
  running = true

  os = {
    type      = "hvm"
    type_arch = "x86_64"
    boot_devices = [
      { dev = "hd" }
    ]
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = var.pool_name
            volume = libvirt_volume.disk.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
        driver = {
          name = "qemu"
          type = "qcow2"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = var.pool_name
            volume = libvirt_volume.cloudinit.name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
        driver = {
          name = "qemu"
          type = "raw"
        }
      }
    ]

    interfaces = [
      {
        source = {
          network = {
            network = var.network_name
          }
        }
        model = {
          type = "virtio"
        }
      }
    ]

    consoles = [
      {
        target = {
          type = "serial"
          port = 0
        }
      }
    ]

    graphics = [
      {
        spice = {
          auto_port = true
        }
      }
    ]
  }
}
