# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "NonpordRG"
  location = "south india"
}

# Create a virtual network/subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "nonprodapp"
  address_space       = ["11.0.0.0/28"]
  location            = "south india"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vnet" {
  name                 = "nonproddb"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["11.0.0.8/29"]
}
resource "azurerm_public_ip" "pub" {
  name                = "public"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "South India"
  allocation_method   = "Static"

  tags = {
    environment = "Non Production"
  }
}
  resource "azurerm_subnet" "vnet2" {
  name                 = "nonprodapp"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["11.0.0.0/29"]
}
resource "azurerm_public_ip" "pub2" {
  name                = "public2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "South India"
  allocation_method   = "Static"
  tags = {
    environment = "Non Production"
  }
}
resource "azurerm_network_interface" "main" {
  name                = "DB-nic"
  location            = "south india"
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "db"
    subnet_id                     = azurerm_subnet.vnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pub.id
  }
}
resource "azurerm_network_interface" "app" {
  name                = "App-nic"
  location            = "south india"
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "app"
    subnet_id                     = azurerm_subnet.vnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pub2.id
  }
}

resource "azurerm_virtual_machine" "server" {
  name                  = "DB-vm"
  location              = "South India"
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "nonprod"
  }
}
# App server
resource "azurerm_virtual_machine" "server2" {
  name                  = "App-vm"
  location              = "South India"
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.app.id]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "nonprod"
  }
}

#Load balencer

 resource "azurerm_public_ip" "pub3" {
  name                = "public3"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "South India"
  allocation_method   = "Static"

  tags = {
    environment = "Non Production"
  }
}
resource "azurerm_public_ip" "publicLB" {
  name                = "PublicIPForLB"
  location            = "South India"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}
resource "azurerm_lb" "LB" {
  name                = "LB-NonProd"
  location            = "South India"
  resource_group_name = azurerm_resource_group.rg.name

    frontend_ip_configuration {
    name                 = "PublicLB"
    public_ip_address_id = azurerm_public_ip.pub3.id
  }
}
resource "azurerm_lb_backend_address_pool" "PrivateLB" {
  loadbalancer_id = azurerm_lb.LB.id
  name            = "Banckebndpool"
  }
resource "azurerm_network_interface_backend_address_pool_association" "example" {
  network_interface_id    = azurerm_network_interface.app.id
  ip_configuration_name   = "testconfiguration1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PrivateLB.id
}
