variable "project" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "rds_sg_id" { type = string }
variable "secret_arn" { type = string }
variable "lambda_package" { type = string } # path to zip file
