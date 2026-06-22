output "vm_ips" {
  value = { for name, mod in module.vms : name => mod.ip_address }
}

output "ssh_commands" {
  value = {
    for name, mod in module.vms :
    name => "ssh -i ~/.ssh/ecommerce_key ubuntu@${mod.ip_address}"
  }
}
