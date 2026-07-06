variable "public_key" {
  description = "SSH public key for the Jenkins EC2 instance"
  type        = string
  sensitive   = true
}