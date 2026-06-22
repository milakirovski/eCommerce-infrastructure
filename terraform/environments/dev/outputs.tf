output "vm_ips" {
  description = "IP addresses of all created VMs"
  value = {
    for name, mod in module.vms : name => mod.ip_address
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to each VM"
  value = {
    for name, mod in module.vms :
    name => "ssh -i ~/.ssh/ecommerce_key ubuntu@${mod.ip_address}"
  }
}
