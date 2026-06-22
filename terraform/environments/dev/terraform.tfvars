# -------------------------------------------------------
# Fill in these values before running terraform apply
# -------------------------------------------------------

libvirt_uri       = "qemu:///system"
storage_pool_path = "/var/lib/libvirt/images/ecommerce-dev"

# Local path to the downloaded Ubuntu 22.04 cloud image.
# Run `make download-image` first.
ubuntu_image_url  = "/tmp/ubuntu-22.04-server-cloudimg-amd64.img"


# Paste the content of ~/.ssh/ecommerce_key.pub here.
# Generate with: ssh-keygen -t ed25519 -f ~/.ssh/ecommerce_key -N ""
ssh_public_key    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM1/LuXlIedWFxM5qI9iWKBm7Q9hyk06/ZONN2CGXiQA ecommerce-iac"
