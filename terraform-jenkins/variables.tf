variable "public_key" {
  description = "SSH public key for the Jenkins EC2 instance"
  type        = string
  sensitive   = true
}

variable "instance_name" {
  type    = string
  default = "jenkins"
}

variable "usage_tag" {
  type    = string
  default = "Jenkins"
}

variable "vpc_cidr" {
  description = "CIDR block for  Jenkins VPC"
  type        = string
  default     = "172.16.0.0/16"
}

variable "security_group_cidr_blocks" {
  type    = string
  default = "0.0.0.0/0" # ALL
}