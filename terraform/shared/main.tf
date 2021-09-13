resource "azurerm_resource_group" "shared" {
  name     = var.resource_group_name
  location = var.location
}

// ACR
resource "azurerm_container_registry" "acr" {
  name                          = var.acrname
  resource_group_name           = azurerm_resource_group.shared.name
  location                      = azurerm_resource_group.shared.location
  sku                           = "Premium"
  admin_enabled                 = true
  public_network_access_enabled = false
}

# VNet
resource "azurerm_virtual_network" "vnet" {
  name                = "shared-vnet"
  address_space       = var.address_space_vnet_shared.vnet
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
}

resource "azurerm_subnet" "acrsubnet" {
  name                                           = "acr-subnet"
  resource_group_name                            = azurerm_resource_group.shared.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = var.address_space_vnet_shared.acrsubnet
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_subnet" "vmsubnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.address_space_vnet_shared.vmsubnet
}


# DNS privado para utilização dos serviços externos ao aks na azure
resource "azurerm_private_dns_zone" "dns" {
  name                = "private.devops.com.br"
  resource_group_name = azurerm_resource_group.shared.name
}

# DNS Privado ACR
resource "azurerm_private_dns_zone" "azurecr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.shared.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "azurecr" {
  name                  = "azurecr"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.azurecr.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "azurecr" {
  name                = "azurecr-private-endpoint"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  subnet_id           = azurerm_subnet.acrsubnet.id

  private_service_connection {
    name                           = "acr-privateconnection"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
}

resource "null_resource" "create_registry_dns" {
  triggers = {
    id = 1
  }
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module
    command     = "./config_dns_acr.sh"
    environment = {
      AZUREACR_NAME = azurerm_container_registry.acr.name
      RG_NAME       = azurerm_resource_group.shared.name
      ENDPOINT_NAME = azurerm_private_endpoint.azurecr.name
    }
  }
}


// VM JUMPBOX
resource "azurerm_public_ip" "pip" {
  name                = "devopsvm-pip"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  allocation_method   = "Static"
}

#tfsec:ignore:AZU017
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "devopsvm-nsg"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "devopsvm-nic"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name

  ip_configuration {
    name                          = "vmNicConfiguration"
    subnet_id                     = azurerm_subnet.vmsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

resource "random_password" "adminpassword" {
  keepers = {
    resource_group = azurerm_resource_group.shared.name
  }

  override_special = "_%@"
  special          = true
  length           = 10
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                            = "devopsvm"
  location                        = azurerm_resource_group.shared.location
  resource_group_name             = azurerm_resource_group.shared.name
  network_interface_ids           = [azurerm_network_interface.vm_nic.id]
  size                            = "Standard_D2s_v3"
  computer_name                   = "devopsvm"
  admin_username                  = "devopsadmin"
  admin_password                  = random_password.adminpassword.result
  disable_password_authentication = false

  os_disk {
    name                 = "devopsvmOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "PRD"
  }
}


resource "azurerm_virtual_machine_extension" "jumpbox" {
  name                 = "hostname"
  virtual_machine_id   = azurerm_linux_virtual_machine.jumpbox.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "${base64encode(file(var.scriptfile))}"
    }
SETTINGS

  tags = {
    environment = "PRD"
  }
}


output "vmpassword" {
  value = random_password.adminpassword.result
}