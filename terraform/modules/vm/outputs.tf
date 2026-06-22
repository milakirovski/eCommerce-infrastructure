output "vm_name" {
  value = libvirt_domain.vm.name
}

output "ip_address" {
  value = var.ip_address
}

output "id" {
  value = libvirt_domain.vm.id
}
