locals {
  env    = terraform.workspace == "deafult" ? "devqas" : terraform.workspace
  isprod = terraform.workspace == "prd"
}

data "azurerm_client_config" "current" {}

data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    resource_group_name  = "devops-terraform"
    storage_account_name = "terraform20210911"
    container_name       = "shared-tfstate"
    key                  = "terraform.tfstate"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_key_vault" "kv" {
  name                = "main20210911-kv"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"
}


# Roles para acesso o AKS ter acesso

resource "azurerm_key_vault_access_policy" "kv-policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

  key_permissions         = ["Get"]
  secret_permissions      = ["Get"]
  certificate_permissions = ["Get"]
}

resource "azurerm_role_assignment" "role_assignment_acr_pull" {
  scope                            = data.terraform_remote_state.shared.outputs.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "netcontributor" {
  role_definition_name = "Network Contributor"
  scope                = azurerm_subnet.subnet.id
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

resource "azurerm_role_assignment" "dns_zone_contributor" {
  role_definition_name = "Private DNS Zone Contributor"
  scope                = data.terraform_remote_state.shared.outputs.private_dns_id
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}




# VNet Aks
resource "azurerm_virtual_network" "vnet" {
  name                = "aks-${local.env}-vnet"
  address_space       = var.kube_network_cidr
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                                           = "default"
  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = var.kube_network_cidr
  service_endpoints                              = ["Microsoft.ContainerRegistry", "Microsoft.Sql", "Microsoft.keyvault"]
  enforce_private_link_endpoint_network_policies = true
}



resource "azurerm_virtual_network_peering" "shdtomain" {
  name                      = "sharedtomain${local.env}"
  resource_group_name       = data.terraform_remote_state.shared.outputs.rg_name
  virtual_network_name      = data.terraform_remote_state.shared.outputs.vnet_name
  remote_virtual_network_id = azurerm_virtual_network.vnet.id
}

resource "azurerm_virtual_network_peering" "maintoshd" {
  name                      = "maintoshared"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = data.terraform_remote_state.shared.outputs.vnet_id
}


data "azurerm_private_dns_zone" "apiaks" {
  name                = replace(azurerm_kubernetes_cluster.aks.private_fqdn, "/^(.*?)\\./", "")
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
}

resource "azurerm_private_dns_zone_virtual_network_link" "apiaks" {
  name                  = data.terraform_remote_state.shared.outputs.vnet_name
  resource_group_name   = data.azurerm_private_dns_zone.apiaks.resource_group_name
  private_dns_zone_name = data.azurerm_private_dns_zone.apiaks.name
  virtual_network_id    = data.terraform_remote_state.shared.outputs.vnet_id
}

# Workspace logs
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "workspace-aks-${local.env}"
  location            = "eastus2"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerNode"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_solution" "akssolution" {
  solution_name         = "ContainerInsights"
  location              = azurerm_log_analytics_workspace.aks.location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.aks.id
  workspace_name        = azurerm_log_analytics_workspace.aks.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}



resource "azurerm_kubernetes_cluster" "aks" {
  name                    = "aks-${local.env}"
  location                = var.location
  kubernetes_version      = var.kube_version
  resource_group_name     = azurerm_resource_group.rg.name
  dns_prefix              = "aks-${local.env}"
  private_cluster_enabled = true

  default_node_pool {
    name                  = "default"
    vm_size               = var.kube_config_node.default.vm_size
    vnet_subnet_id        = azurerm_subnet.subnet.id
    enable_auto_scaling   = true
    availability_zones    = local.isprod ? [1, 2, 3] : null
    type                  = "VirtualMachineScaleSets"
    enable_node_public_ip = false
    min_count             = var.kube_config_node.default.min_count
    max_count             = var.kube_config_node.default.max_count
    max_pods              = 40
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control {
    enabled = true

    azure_active_directory {
      managed            = true
      tenant_id          = data.azurerm_client_config.current.tenant_id
      azure_rbac_enabled = true
      admin_group_object_ids = [var.admin_group_id]
    }
  }

  addon_profile {
    azure_policy { enabled = true }
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
    }
  }

  network_profile {
    network_policy     = "azure"
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    docker_bridge_cidr = "172.17.0.1/16"
    network_plugin     = "azure"
    outbound_type      = "loadBalancer"
    load_balancer_sku  = "Standard"
  }

  tags = {
    Environment = local.env
  }
}

