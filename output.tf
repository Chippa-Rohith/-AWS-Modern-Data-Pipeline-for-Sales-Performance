output "rds_endpoint" {
  value       = module.rds_mysql.rds_endpoint
  description = "RDS endpoint"
}

output "rds_secret_arn" {
  value       = module.rds_mysql.rds_secret_arn
  description = "Secrets Manager ARN with DB credentials"
}


output "s3_bucket_name" {
  value = module.dms.s3_bucket_name
}

output "s3_bucket_arn" {
  value = module.dms.s3_bucket_arn
}