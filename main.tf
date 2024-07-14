terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "az-k8s-cluster" {
  name     = "az-k8s-cluster-test"
  location = "swedencentral"
}

resource "azurerm_virtual_network" "k8s-vnet" {
  name                = "az-k8s-cluster-test"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.az-k8s-cluster.location
  resource_group_name = azurerm_resource_group.az-k8s-cluster.name
}

resource "azurerm_subnet" "k8s-subnet" {
  name                 = "az-k8s-snet1"
  address_prefixes     = ["10.0.1.0/24"]
  virtual_network_name = azurerm_virtual_network.k8s-vnet.name
  resource_group_name  = azurerm_resource_group.az-k8s-cluster.name
}

resource "azurerm_network_security_group" "k8s-nsg" {
  name                = "az-k8s-nsg1"
  location            = azurerm_resource_group.az-k8s-cluster.location
  resource_group_name = azurerm_resource_group.az-k8s-cluster.name
}

resource "azurerm_network_security_rule" "security-rule" {
  count                       = length(var.allowed_ports)
  name                        = "SecurityRule-${element(split(":", var.allowed_ports[count.index]), 0)}"
  priority                    = 1000 + count.index
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = element(split(":", var.allowed_ports[count.index]), 1)
  source_port_range           = "*"
  destination_port_range      = element(split(":", var.allowed_ports[count.index]), 0)
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.k8s-nsg.name
  resource_group_name         = azurerm_resource_group.az-k8s-cluster.name
}

resource "azurerm_subnet_network_security_group_association" "k8s-nsga" {
  subnet_id                 = azurerm_subnet.k8s-subnet.id
  network_security_group_id = azurerm_network_security_group.k8s-nsg.id
}

resource "azurerm_public_ip" "k8s-master-pip" {
  count               = var.masters_count
  name                = "k8s-master_pip-${count.index}"
  resource_group_name = azurerm_resource_group.az-k8s-cluster.name
  location            = azurerm_resource_group.az-k8s-cluster.location
  allocation_method   = "Dynamic"
  sku                 = "Basic"
  depends_on          = [azurerm_virtual_network.k8s-vnet, azurerm_subnet.k8s-subnet]
}

resource "azurerm_public_ip" "k8s-worker-pip" {
  count               = var.workers_count
  name                = "k8s-worker-pip-${count.index}"
  resource_group_name = azurerm_resource_group.az-k8s-cluster.name
  location            = azurerm_resource_group.az-k8s-cluster.location
  allocation_method   = "Dynamic"
  sku                 = "Basic"
  depends_on          = [azurerm_virtual_network.k8s-vnet, azurerm_subnet.k8s-subnet]
}

resource "azurerm_network_interface" "k8s-master" {
  count                = var.masters_count
  name                 = "nic-k8s-master-${count.index}"
  location             = azurerm_resource_group.az-k8s-cluster.location
  resource_group_name  = azurerm_resource_group.az-k8s-cluster.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s-subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.k8s-master-pip[count.index].id
  }
}

resource "azurerm_network_interface" "k8s-worker" {
  count                = var.workers_count
  name                 = "nic-k8s-worker-${count.index}"
  location             = azurerm_resource_group.az-k8s-cluster.location
  resource_group_name  = azurerm_resource_group.az-k8s-cluster.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s-subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.k8s-worker-pip[count.index].id
  }
}

resource "azurerm_virtual_machine" "k8s-master-vm" {
  count                 = var.masters_count
  name                  = "k8s-master-vm${count.index}"
  location              = azurerm_resource_group.az-k8s-cluster.location
  resource_group_name   = azurerm_resource_group.az-k8s-cluster.name
  vm_size               = var.vm_master_size
  network_interface_ids = [azurerm_network_interface.k8s-master[count.index].id]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "k8s-disk-k8s-master${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 50
  }


  os_profile {
    admin_username = "k8s-master"
    computer_name  = "k8s-master${count.index}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file("~/.ssh/id_rsa.pub")
      path     = "/home/k8s-master/.ssh/authorized_keys"
    }
  }
  depends_on = [azurerm_network_interface.k8s-master]
}


resource "azurerm_virtual_machine" "k8s-worker-vm" {
  count                 = var.workers_count
  name                  = "k8s-worker-vm${count.index}"
  location              = azurerm_resource_group.az-k8s-cluster.location
  resource_group_name   = azurerm_resource_group.az-k8s-cluster.name
  vm_size               = var.vm_worker_size
  network_interface_ids = [azurerm_network_interface.k8s-worker[count.index].id]
  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "k8s-disk-worker${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    admin_username = "k8s-worker"
    computer_name  = "k8s-worker${count.index}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file("~/.ssh/id_rsa.pub")
      path     = "/home/k8s-worker/.ssh/authorized_keys"
    }
  }
  depends_on = [azurerm_network_interface.k8s-worker]
}
