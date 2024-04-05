
# Guest
guest_template        = "io-ubuntu-22.04-template"
guest_ssh_user        = "root"
guest_ssh_password    = "dangerous"
guest_ssh_key_private = "~/.ssh/id_rsa"
guest_ssh_key_public  = "~/.ssh/id_rsa.pub"



networks = [
  {
    name = "VM Network"
    gateway = "192.168.1.1"
    netmask = "24"
    dns_servers = ["192.168.1.3","192.168.2.4"]
    dns_search = ["aceshome.com", "internal.aceshome.com", "stratolinux.io"]
    domain = "aceshome.com"
  },
  {
    name = "Test Network"
    gateway = "192.168.2.1"
    netmask = "24"
    dns_servers = ["192.168.2.4", "192.168.1.3"]
    dns_search = ["stratolinux.io", "internal.aceshome.com", "aceshome.com"]
    domain = "stratolinux.io"
  }
]
