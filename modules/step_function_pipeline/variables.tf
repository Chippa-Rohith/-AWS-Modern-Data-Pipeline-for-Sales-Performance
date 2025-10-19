variable "name" {
  description = "Name of the Step Function state machine"
  type        = string
}

variable "redshift_secret_arn" {
  description = "Secrets Manager ARN for Redshift"
  type        = string
}

variable "workgroup_name" {
  description = "Redshift Serverless Workgroup Name"
  type        = string
}
