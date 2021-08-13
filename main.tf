resource "azurerm_resource_group" "resourcegroup" {
  name     = var.rgname
  location = var.location
  tags = var.tags

  provisioner "local-exec" {
    command = "echo '${self.id}' "
  }
}

resource "azurerm_virtual_network" "main_network" {
  name                           = var.main_network_name
  resource_group_name            = var.rgname
  location                       = var.location
  address_space                  = var.main_address_space
}

resource "azurerm_subnet" "internal_subnet" {
#  count                         = length(var.internal_subnet_address_space)
  count                  = var.internal_subnet_address_count
  name                   = "${var.subnet_name}-${count.index}"
  resource_group_name    = var.rgname
  virtual_network_name   = azurerm_virtual_network.main_network.name
  address_prefixes       = [element(var.internal_subnet_address_space, count.index)]
}

resource "azurerm_network_security_group" "security_group" {

  name                = var.security_group_name
  location            = var.location
  resource_group_name = var.rgname


  dynamic "security_rule" {
    for_each = var.inbound_port_ranges
    content {
      name                       = "rule-${security_rule.value}"
      priority                   = security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}
#resource "azurerm_network_security_rule" "security_group_rule" {
#  count                       = length(var.inbound_port_ranges)
#  name                        = "rule-${element(var.inbound_port_ranges, count.index)}"
#  priority                    = "${(100 * (count.index + 1))}"
#  direction                   = "Inbound"
#  access                      = "Allow"
#  protocol                    = "Tcp"
#  source_port_range           = "*"
#  destination_port_range      = "*"
#  source_address_prefix       = "*"
#  destination_address_prefix  = element(var.inbound_port_ranges, count.index)
#  resource_group_name         = var.rgname
#  network_security_group_name = var.security_group_name
#}

resource "azurerm_subnet_network_security_group_association" "security_group_associate" {
  count 					= var.internal_subnet_address_count
  subnet_id                 = element(azurerm_subnet.internal_subnet.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.security_group.id
}

resource "azurerm_network_interface" "main_interface" {
  count 			  = var.internal_subnet_address_count
  name                = "vm-int-${count.index}"
  location            = var.location
  resource_group_name = var.rgname

  ip_configuration {
    name                          = "ip-vm-${count.index}"
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = azurerm_public_ip.public_ip.id
    subnet_id                     = element(azurerm_subnet.internal_subnet.*.id, count.index)
  }
}

resource "azurerm_virtual_machine" "vm_main" {
  count 						   = length(azurerm_network_interface.main_interface.*.id)
  name                             = "vm-${count.index}"
  location                         = var.location
  resource_group_name              = var.rgname
  network_interface_ids            = [element(azurerm_network_interface.main_interface.*.id, count.index)]
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
    name              = "vm-osdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = 30
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vm-${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234"
  }
   os_profile_linux_config {
    disable_password_authentication = false
  }
}