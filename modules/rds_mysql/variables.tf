variable "project" {
  type        = string
  description = "Project prefix"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "allowed_cidr" {
  type        = string
  description = "CIDR block allowed to access MySQL"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance size"
  default     = "db.t3.micro"
}

variable "db_name" {
  type        = string
  description = "Initial DB name"
  default     = "salesdb"
}

variable "db_username" {
  type        = string
  description = "RDS master username"
  default     = "admin"
}


variable "key_pair_name" {
  description = "EC2 Key Pair name for bastion host"
  type        = string
}