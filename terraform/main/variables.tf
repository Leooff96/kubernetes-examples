variable "location" {
  description = "The resource group location"
  default     = "East US 2"
}

variable "locationtrim" {
  default = "eastus2"
}

variable "resource_group_name" {
  description = "The resource group name to be used"
  default     = "main-devqas"
}

variable "shared_resource_group_name" {
  description = "The resource group name to be used"
  default     = "shared"
}

variable "ad_tenant_id" {
  description = "Tenant Id Active Directory"
  default     = "ce1cf08e-140c-44fa-b94a-c0c56618f999"
}

variable "kube_network_cidr" {
  description = "VNET Kubernetes cidr"
  default     = ["10.4.4.0/22"]
}

variable "kube_version" {
  description = "AKS Kubernetes version"
  default     = "1.20.7"
}

variable "kube_config_node" {
  default = {
    default = {
      min_count = 1
      max_count = 1
      vm_size   = "Standard_D2s_v3"
    }
  }
}

variable "service_cidr" {
  default = "10.2.0.0/22"
}
variable "dns_service_ip" {
  default = "10.2.0.10"
}

variable "admin_group_id" {
  default = "7660635c-8fa8-489f-8d1b-18763fed3e06"
}