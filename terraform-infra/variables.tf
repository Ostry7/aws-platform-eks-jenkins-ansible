variable "region" {
    description =  "Specify AWS region"
    type = string
    default = "eu-north-1"
}

variable "eks_cluster_name" {
    description = "Name of the EKS cluster"
    type = string
    default = "K8s_cluster"
}

variable "instance_type" {
    description = "EC2 instance type for worker nodes"
    type = string
    default = "t3.micro"
}

variable "node_desired_capacity" {
    description = "Desired number of worker nodes"
    type = number
    default = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az1_cidr" {
  description = "CIDR block for AZ1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "az2_cidr" {
  description = "CIDR block for AZ2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "az3_cidr" {
  description = "CIDR block for AZ3"
  type        = string
  default     = "10.0.3.0/24"
}