##### Provider
# - Arguments to configure the VMware vSphere Provider

variable "provider_vsphere_host" {
  description = "vCenter server FQDN or IP - Example: vcsa01-z67.sddc.lab"
}

variable "provider_vsphere_user" {
  description = "vSphere username to use to connect to the environment - Default: administrator@vsphere.local"
  default     = "administrator@vsphere.local"
}

variable "provider_vsphere_password" {
  description = "vSphere password"
}

#####
##### Cluster/Node configuration
#####
variable "cluster_nodes" {
    type = object({
        masters = object({
          prefix = string
          memory = string
          cpu = string
          extra_disks = list(string)
          ips = list(string)
          gateway = string
        })
        workers = object({
          prefix = string
          memory = string
          cpu = string
          extra_disks = list(string)
          ips = list(string)
          gateway = string
        })
        datacenter: string
        cluster: string
        datastore: string
        vapp: string
        folder: string
        resourcepool: string
        workspace: string
    })
}

#####
##### Network Settings
#####
variable "networks" {
  type = list(object({
    name = string
    gateway = string
    netmask = string
    dns_servers = list(string)
    dns_search = list(string)
    domain = string
  }))
}


#####
##### Common settings
#####

variable "guest_template" {
  description = "The source virtual machine or template to clone from."
}

variable "guest_ssh_user" {
  description = "SSH username to connect to the guest VM."
}

variable "guest_ssh_password" {
  description = "SSH password to connect to the guest VM."
}

variable "guest_ssh_key_private" {
  description = "SSH private key (e.g., id_rsa) path."
}

variable "guest_ssh_key_public" {
  description = "SSH public key (e.g., id_rsa.pub) path."
}
