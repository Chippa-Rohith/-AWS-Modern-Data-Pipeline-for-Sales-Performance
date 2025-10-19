variable "project" {}
variable "private_subnet_ids" {
  type = list(string)
}
variable "rds_sg_id" {}
variable "rds_endpoint" {}
variable "secret_arn" {}

variable "db_name" {
  type        = string
  description = "Initial DB name"
  default     = "salesdb"
}

variable "region" {
  description = "AWS region where resources are deployed"
}
