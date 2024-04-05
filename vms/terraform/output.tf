### Output definitions


### The Ansible inventory file
# If anything is added here, also update the inventory.tmpl template
resource "local_file" "ansible_inventory" {
 content = templatefile("inventory.tmpl",
  {
  # variables to be set
  ssh_key = var.guest_ssh_key_private

  # master node information
  master_prefix = var.cluster_nodes.masters.prefix
  master_ip = vsphere_virtual_machine.kubernetes_masters.*.default_ip_address

  # worker node information
  worker_prefix = var.cluster_nodes.workers.prefix
  worker_ip = vsphere_virtual_machine.kubernetes_workers.*.default_ip_address

  }
 )
 filename = "../inventory"
}

