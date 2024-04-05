##### Terraform Initialization
terraform {
  required_version = ">= 0.13"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "1.24.3"
    }
  }
}

##### Provider
provider "vsphere" {
  user           = var.provider_vsphere_user
  password       = var.provider_vsphere_password
  vsphere_server = var.provider_vsphere_host

  # if you have a self-signed cert
  allow_unverified_ssl = true
}

##### Data sources
data "vsphere_datacenter" "target_dc" {
  name = var.cluster_nodes.datacenter
}

data "vsphere_datastore" "target_datastore" {
  name          = var.cluster_nodes.datastore
  datacenter_id = data.vsphere_datacenter.target_dc.id
}

data "vsphere_compute_cluster" "target_cluster" {
  name          = var.cluster_nodes.cluster
  datacenter_id = data.vsphere_datacenter.target_dc.id
}

data "vsphere_network" "master_network" {
  name          = var.networks[index(var.networks.*.gateway, var.cluster_nodes.masters.gateway)].name
  datacenter_id = data.vsphere_datacenter.target_dc.id
}

data "vsphere_network" "worker_network" {
  name          = var.networks[index(var.networks.*.gateway, var.cluster_nodes.workers.gateway)].name
  datacenter_id = data.vsphere_datacenter.target_dc.id
}


data "vsphere_virtual_machine" "source_template" {
  name          = var.guest_template
  datacenter_id = data.vsphere_datacenter.target_dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.cluster_nodes.resourcepool
  datacenter_id = data.vsphere_datacenter.target_dc.id
}


data "vsphere_folder" "target_folder" {
  path          = var.cluster_nodes.folder
}

#####
##### Resources
#####

# vApp
#resource "vsphere_vapp_container" "vapp_container" {
#  name          = var.deploy_vsphere_vapp
#  parent_folder_id     = "${data.vsphere_folder.target_folder.id}"
#  parent_resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
#}

# Clones a single Linux VM from a template
resource "vsphere_virtual_machine" "kubernetes_masters" {
  count            = length(var.cluster_nodes.masters.ips)
  name             = format("%s.%s", replace("${var.cluster_nodes.masters.prefix}-${var.cluster_nodes.masters.ips[count.index]}", ".", "-"), "${var.networks[index(var.networks.*.gateway, var.cluster_nodes.masters.gateway)].domain}")
  #resource_pool_id = "${vsphere_vapp_container.vapp_container.id}"
  resource_pool_id = "${data.vsphere_compute_cluster.target_cluster.resource_pool_id}"
  folder           = "${data.vsphere_folder.target_folder.path}"
  datastore_id     = data.vsphere_datastore.target_datastore.id
  #folder           = var.deploy_vsphere_folder

  num_cpus = var.cluster_nodes.masters.cpu
  memory   = var.cluster_nodes.masters.memory
  guest_id = data.vsphere_virtual_machine.source_template.guest_id

  scsi_type = data.vsphere_virtual_machine.source_template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.master_network.id
    adapter_type = data.vsphere_virtual_machine.source_template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.source_template.disks[0].size
    eagerly_scrub    = data.vsphere_virtual_machine.source_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.source_template.disks[0].thin_provisioned
  }


  dynamic "disk" {
    for_each = var.cluster_nodes.masters.extra_disks

    content {
      label            = format("disk%d", disk.key+1)
      size             = "${disk.value}"
      unit_number      = disk.key+1
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.source_template.id

    customize {
      linux_options {
        host_name = replace("${var.cluster_nodes.masters.prefix}-${var.cluster_nodes.masters.ips[count.index]}", ".", "-" )
        domain    = var.networks[index(var.networks.*.gateway, var.cluster_nodes.masters.gateway)].domain
      }

      network_interface {
        ipv4_address = var.cluster_nodes.masters.ips[count.index]
        ipv4_netmask = var.networks[index(var.networks.*.gateway, var.cluster_nodes.masters.gateway)].netmask
      }

      ipv4_gateway    = var.cluster_nodes.masters.gateway
      dns_server_list = var.networks[index(var.networks.*.gateway, var.cluster_nodes.masters.gateway)].dns_servers
      dns_suffix_list = var.networks[index(var.networks.*.gateway, var.cluster_nodes.masters.gateway)].dns_search
    }
  }

  boot_delay = 10000

  # Remove existing SSH known hosts as remote identification (host key) changes between deployments.
  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.guest_ip_addresses[0]}"
  }

  # Disabling SSH authenticity checking StrictHostKeyChecking=no, to avoid beeing asked to add RSA key fingerprint of a host when you access it for the first time.
  provisioner "local-exec" {
    command = "sshpass -p ${var.guest_ssh_password} ssh-copy-id -i ${var.guest_ssh_key_public} -o StrictHostKeyChecking=no ${var.guest_ssh_user}@${self.guest_ip_addresses[0]}"
  }

  # Copies the ssh keys
  provisioner "file" {
    source      = "${var.guest_ssh_key_public}"
    destination = "/root/.ssh/id_rsa.pub"

    connection {
      type     = "ssh"
      user     = "root"
      password = "${var.guest_ssh_password}"
      host     = "${self.guest_ip_addresses[0]}"
    }
  }

  # Copies the ssh keys
  provisioner "file" {
    source      = "${var.guest_ssh_key_private}"
    destination = "/root/.ssh/id_rsa"

    connection {
      type     = "ssh"
      user     = "root"
      password = "${var.guest_ssh_password}"
      host     = "${self.guest_ip_addresses[0]}"
    }
  }

  # Copies the ssh keys
  provisioner "remote-exec" {
    inline = [
      "chmod 700 /root/.ssh && chmod 644 /root/.ssh/id_rsa.pub && chmod 600 /root/.ssh/id_rsa"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      password = "${var.guest_ssh_password}"
      host     = "${self.guest_ip_addresses[0]}"
    }
  }


  lifecycle {
    ignore_changes = [annotation]
  }
}

# Clones multiple Linux VMs from a template
resource "vsphere_virtual_machine" "kubernetes_workers" {
  count            = length(var.cluster_nodes.workers.ips)
  name             = format("%s.%s", replace("${var.cluster_nodes.workers.prefix}-${var.cluster_nodes.workers.ips[count.index]}", ".", "-"), "${var.networks[index(var.networks.*.gateway, var.cluster_nodes.workers.gateway)].domain}")
  #resource_pool_id = "${vsphere_vapp_container.vapp_container.id}"
  resource_pool_id = "${data.vsphere_compute_cluster.target_cluster.resource_pool_id}"
  folder           = "${data.vsphere_folder.target_folder.path}"
  datastore_id     = data.vsphere_datastore.target_datastore.id
  #folder           = var.deploy_vsphere_folder

  num_cpus = var.cluster_nodes.workers.cpu
  memory   = var.cluster_nodes.workers.memory
  guest_id = data.vsphere_virtual_machine.source_template.guest_id

  scsi_type = data.vsphere_virtual_machine.source_template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.worker_network.id
    adapter_type = data.vsphere_virtual_machine.source_template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.source_template.disks[0].size
    eagerly_scrub    = data.vsphere_virtual_machine.source_template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.source_template.disks[0].thin_provisioned
  }

  dynamic "disk" {
    for_each = var.cluster_nodes.workers.extra_disks

    content {
      label            = format("disk%d", disk.key+1)
      size             = "${disk.value}"
      unit_number      = disk.key+1
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.source_template.id

    customize {
      linux_options {
        host_name = replace("${var.cluster_nodes.workers.prefix}-${var.cluster_nodes.workers.ips[count.index]}", ".", "-" )
        domain    = var.networks[index(var.networks.*.gateway, var.cluster_nodes.workers.gateway)].domain
      }

      network_interface {
        ipv4_address = var.cluster_nodes.workers.ips[count.index]
        ipv4_netmask = var.networks[index(var.networks.*.gateway, var.cluster_nodes.workers.gateway)].netmask
      }

      ipv4_gateway    = var.cluster_nodes.workers.gateway
      dns_server_list = var.networks[index(var.networks.*.gateway, var.cluster_nodes.workers.gateway)].dns_servers
      dns_suffix_list = var.networks[index(var.networks.*.gateway, var.cluster_nodes.workers.gateway)].dns_search
    }
  }

  boot_delay = 10000

  # Remove existing SSH known hosts as remote identification (host key) changes between deployments.
  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.guest_ip_addresses[0]}"
  }

  # Disabling SSH authenticity checking StrictHostKeyChecking=no, to avoid beeing asked to add RSA key fingerprint of a host when you access it for the first time.
  provisioner "local-exec" {
    command = "sshpass -p ${var.guest_ssh_password} ssh-copy-id -i ${var.guest_ssh_key_public} -o StrictHostKeyChecking=no ${var.guest_ssh_user}@${self.guest_ip_addresses[0]}"
  }

  # Copies the ssh keys
  provisioner "file" {
    source      = "${var.guest_ssh_key_public}"
    destination = "/root/.ssh/id_rsa.pub"

    connection {
      type     = "ssh"
      user     = "root"
      password = "${var.guest_ssh_password}"
      host     = "${self.guest_ip_addresses[0]}"
    }
  }

  # Copies the ssh keys
  provisioner "file" {
    source      = "${var.guest_ssh_key_private}"
    destination = "/root/.ssh/id_rsa"

    connection {
      type     = "ssh"
      user     = "root"
      password = "${var.guest_ssh_password}"
      host     = "${self.guest_ip_addresses[0]}"
    }
  }

  # Copies the ssh keys
  provisioner "remote-exec" {
    inline = [
      "chmod 700 /root/.ssh && chmod 644 /root/.ssh/id_rsa.pub && chmod 600 /root/.ssh/id_rsa"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      password = "${var.guest_ssh_password}"
      host     = "${self.guest_ip_addresses[0]}"
    }
  }

  lifecycle {
    ignore_changes = [annotation]
  }
}

