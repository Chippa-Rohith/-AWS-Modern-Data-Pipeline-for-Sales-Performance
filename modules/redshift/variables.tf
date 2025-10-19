variable "project" {}
variable "vpc_id" {}
variable "private_subnet_ids" {
  type = list(string)
}
variable "allowed_cidr" {
  default = "0.0.0.0/0"
}
variable "db_name" {
  default = "dev"
}
variable "admin_username" {
  default = "admin"
}
variable "s3_bucket" {
  description = "S3 bucket name for COPY/UNLOAD"
}
variable "base_rpus" {
  default = 8
}
variable "max_rpus" {
  default = 32
}
