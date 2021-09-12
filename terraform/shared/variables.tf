
variable "resource_group_name" {
  description = "The resource group name to be used"
  default     = "shared-devops"
}

variable "location" {
  description = "The resource group location"
  default     = "East US 2"
}

variable "address_space_vnet_shared" {
  default = {
    vnet      = ["10.0.0.0/25"]
    acrsubnet = ["10.0.0.32/27"]
    vmsubnet  = ["10.0.0.64/27"]
  }
}

variable "scriptfile" {
  type = string
  default = "startupVM.sh"
}

variable "acrname" {
  default = "devops20210911"
}