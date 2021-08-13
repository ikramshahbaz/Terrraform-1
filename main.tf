provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resourcegroup" {
  name     = var.rgname
  location = var.location
  tags = {
    name = "ikram"
  }

  provisioner "local-exec" {
    command = "echo '${self.id}' "
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "key-vault" {
  depends_on                  = [azurerm_resource_group.resourcegroup]
  name                        = "shahbazikram"
  location                    = var.location
  resource_group_name         = var.rgname
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "get",
    ]
    secret_permissions = [
      "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
    ]
  }
}


resource "azurerm_key_vault_secret" "vm_password" {
  name         = "linux-vm-password"
  value        = "Azure@1234"
  key_vault_id = azurerm_key_vault.key-vault.id
  depends_on   = [azurerm_key_vault.key-vault]
}


resource "azurerm_virtual_network" "main" {
  name                = "network-metis"
  resource_group_name = var.rgname
  location            = var.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "internal" {
  name                 = "testsubnet"
  resource_group_name  = var.rgname
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "security_group" {
  name                = "acceptanceTestSecurityGroup1"
  location            = var.location
  resource_group_name = var.rgname

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}


resource "azurerm_subnet_network_security_group_association" "security_group_associate" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.security_group.id
}

resource "azurerm_public_ip" "public_ip" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = var.rgname
  location            = var.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "main1" {
  name                = "vm-01-nic"
  location            = var.location
  resource_group_name = var.rgname

  ip_configuration {
    name                          = "ip-vm-01"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
    subnet_id                     = azurerm_subnet.internal.id
  }
}



resource "azurerm_virtual_machine" "main2" {
  name                             = "vm-01"
  location                         = var.location
  resource_group_name              = var.rgname
  network_interface_ids            = [azurerm_network_interface.main1.id]
  vm_size                          = "Standard_DS1_v2"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "vm-01-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = 30
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vm-01"
    admin_username = "testadmin"
    admin_password = azurerm_key_vault_secret.vm_password.value
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}