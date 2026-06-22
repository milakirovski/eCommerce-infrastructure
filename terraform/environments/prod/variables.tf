variable "libvirt_uri" {
  type    = string
  default = "qemu:///system"
}

variable "storage_pool_path" {
  type    = string
  default = "/var/lib/libvirt/images/ecommerce-prod"
}

variable "ubuntu_image_url" {
  type = string
}

variable "ssh_public_key" {
  type = string
}
