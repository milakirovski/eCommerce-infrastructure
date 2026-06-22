version: 2
ethernets:
  mainif:
    match:
      name: "en*"
    dhcp4: false
    addresses:
      - ${ip_address}/24
    routes:
      - to: default
        via: ${gateway}
    nameservers:
      addresses: [${join(", ", dns_servers)}]
