variable "rgname"  {
        type = string
}

variable "location" {
        type = string
}


variable "main_network_name" {
        type = string
}

variable "main_address_space" {
        type = list(string)
}

variable "tags" {
        type  = map(string)
}

variable "subnet_name" {
        type = string
}

variable "internal_subnet_address_count" {
        type = number
}

variable "internal_subnet_address_space" {
        type = list(string)
}

variable "security_group_name" {
  type    = string
}

variable "inbound_port_ranges" {
  type = any
}