variable "allowed_ports" {
  default = [
    "22:Tcp",
    "443:Tcp",
    "80:Tcp",
    "6443:Tcp",
    "0:Icmp",
    "4789:Udp"
  ]
}

variable "masters_count" {
  description = "Number of master nodes"
  default     = 3
}

variable "workers_count" {
  description = "Number of worker nodes"
  default     = 3
}

variable "vm_master_size" {
  default = "Standard_B2s"
}

variable "vm_worker_size" {
  default = "Standard_B2s"
}
