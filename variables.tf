variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Project prefix"
  type        = string
  default     = "sales-pipeline"
}

variable "allowed_cidr" {
  description = "CIDR for RDS access (your public IP/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for bastion host"
  type        = string
  default     = "my-bastion-key"
}
