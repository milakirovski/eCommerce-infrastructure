terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

# VM disk — cloned from the base Ubuntu cloud image
resource "libvirt_volume" "disk" {
  name           = "${var.vm_name}-disk.qcow2"
  pool           = var.pool_name
  base_volume_id = var.base_volume_id
  format         = "qcow2"
  size           = var.disk_size
}

# cloud-init ISO — injected at first boot to set hostname, user, SSH key, and static IP
resource "libvirt_cloudinit_disk" "cloud_init" {
  name = "${var.vm_name}-cloud-init.iso"
  pool = var.pool_name

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

# The virtual machine itself
resource "libvirt_domain" "vm" {
  name   = var.vm_name
  vcpu   = var.vcpu
  memory = var.memory

  disk {
    volume_id = libvirt_volume.disk.id
  }

  cloudinit = libvirt_cloudinit_disk.cloud_init.id

  network_interface {
    network_name   = var.network_name
    addresses      = [var.ip_address]
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
