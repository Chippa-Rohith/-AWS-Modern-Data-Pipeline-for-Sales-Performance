output "replication_task_arn" {
  value = aws_dms_replication_task.this.replication_task_arn
}

output "replication_task_console_url" {
  value = "https://console.aws.amazon.com/dms/v2/home?region=${var.region}#taskDetails/${aws_dms_replication_task.this.replication_task_arn}"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.sales_pipeline.bucket
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.sales_pipeline.arn
}