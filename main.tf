# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.70.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "0000000000000"
}

# Variáveis
variable "location" {
  description = "A região onde os recursos serão criados"
  default     = "West Europe"
}

variable "resource_group_name" {
  description = "Nome do grupo de recursos"
  default     = "rg-vm-ubuntu-nginx"
}

variable "vm_name" {
  description = "Nome da máquina virtual"
  default     = "vm-ubuntu-nginx"
}

variable "admin_username" {
  description = "Nome de usuário administrador"
  default     = "adminuser"
}

variable "public_key" {
  description = "Chave pública SSH"
  type        = string
}

# Criação do Grupo de Recursos
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Criação da Rede Virtual
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.vm_name}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Criação da Sub-rede
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-${var.vm_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Criação do IP Público
resource "azurerm_public_ip" "publicip" {
  name                = "publicip-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  	sku               = "Standard"
  allocation_method   = "Static"
  ip_version          = "IPv4"
}

# Criação do Grupo de Segurança de Rede (NSG) e regras
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Criação da Interface de Rede
resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Associação do NSG à Interface de Rede
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Criação da Máquina Virtual
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

# Saída do IP Público
output "public_ip_address" {
  value = azurerm_public_ip.publicip.ip_address
}
