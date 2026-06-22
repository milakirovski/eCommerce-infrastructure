variable "libvirt_uri" {
  description = "Connection URI for libvirt (local KVM/QEMU)"
  type        = string
  default     = "qemu:///system"
}

variable "storage_pool_path" {
  description = "Filesystem path where VM disk images will be stored"
  type        = string
  default     = "/var/lib/libvirt/images/ecommerce-dev"
}

variable "ubuntu_image_url" {
  description = "URL or local path of the Ubuntu 22.04 cloud image (.qcow2)"
  type        = string
  # Download once with: make download-image
  # Then set this to the local path, e.g. /tmp/ubuntu-22.04-server-cloudimg-amd64.img
}

variable "ssh_public_key" {
  description = "SSH public key injected into every VM (content, not path)"
  type        = string
}
