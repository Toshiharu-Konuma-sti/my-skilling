
# リソース名の接頭辞
variable "project_prefix" {
  description = "Prefix for all resource names and tags"
  type        = string
  default     = "sios-api-sl"
}

# EC2 SSH Key名
variable "ec2_ssh_key_name" {
  description = "EC2 SSH Key pair name"
  type        = string
  default     = "my-ec2-key-pair"
}

# 許可するIPアドレス (CIDR)
variable "allowed_cidr" {
  description = "CIDR block allowed to access SSH and Web UI"
  type        = string
  default     = "0.0.0.0/0"
}

# Artifactoryのノード数
variable "artifactory_node_count" {
  description = "Number of Artifactory nodes to deploy"
  type        = number
  default     = 1
}
