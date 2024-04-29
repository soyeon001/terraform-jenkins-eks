variable "vpc_cidr" {
  description = "VPC CIDR"
  type = string
}

variable "private_subnets" {
    description = "Private Subnet CIDR"
    type = list(string)
}
variable "public_subnets" {
    description = "Public Subnet CIDR"
    type = list(string)
}
