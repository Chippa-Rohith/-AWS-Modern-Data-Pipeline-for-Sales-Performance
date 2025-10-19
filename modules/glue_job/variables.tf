variable "project" {}
variable "glue_service_role_arn" {}   # Reuse from glue_crawler module
variable "scripts_bucket" {}          # Your existing bucket where script is stored
variable "s3_bucket" {}
variable "glue_database_name" {}


variable "vpc_id" {
  description = "VPC ID where Glue connection will be created"
  type        = string
}

variable "redshift_endpoint" {
  description = "Redshift cluster endpoint"
  type        = string
}

variable "redshift_database" {
  description = "Redshift database name"
  type        = string
  default     = "dev"
}

variable "redshift_username" {
  description = "Redshift admin username"
  type        = string
}

variable "redshift_password" {
  description = "Redshift admin password"
  type        = string
  sensitive   = true
}

variable "redshift_security_group_id" {
  description = "Security group ID for Redshift"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for Glue connection"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for Glue connection"
  type        = string
}

variable "redshift_secret_arn" {
  description = "ARN of the Redshift credentials secret in Secrets Manager"
  type        = string
}