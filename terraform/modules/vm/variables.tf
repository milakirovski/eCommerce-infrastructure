variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vcpu" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 1
}

variable "memory" {
  description = "RAM in megabytes"
  type        = number
  default     = 1024
}

variable "disk_size" {
  description = "Disk size in bytes"
  type        = number
  default     = 10737418240 # 10 GB
}

variable "pool_name" {
  description = "Name of the libvirt storage pool"
  type        = string
}

variable "base_volume_path" {
  description = "Filesystem path to the base OS volume to use as backing store"
  type        = string
}

variable "network_name" {
  description = "Name of the libvirt network to attach to"
  type        = string
}

variable "ip_address" {
  description = "Static IP address for this VM"
  type        = string
}

variable "gateway" {
  description = "Default gateway for the network"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS server IPs"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "ssh_public_key" {
  description = "SSH public key to inject via cloud-init"
  type        = string
}
