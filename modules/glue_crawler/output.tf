output "glue_crawler_name" {
  value = aws_glue_crawler.bronze_crawler.name
}

output "glue_service_role_arn" {
  value = aws_iam_role.glue_service_role.arn
}
