variable "project" {
  type        = string
  description = "Project name prefix"
}

variable "glue_database_name" {
  type        = string
  description = "Glue database where crawler will store tables"
}

variable "bronze_s3_path" {
  type        = string
  description = "S3 path for Bronze layer data (e.g., s3://bucket/bronze-data/)"
}

variable "bronze_s3_arn" {
  type        = string
  description = "S3 arn"
}

variable "crawler_schedule" {
  type        = string
  default     = "" # Leave empty if you don't want schedule
  description = "Cron expression for crawler schedule (optional)"
}


variable "bronze_tables" {
  description = "List of table folders inside bronze-data/salesdb"
  type        = list(string)
}
