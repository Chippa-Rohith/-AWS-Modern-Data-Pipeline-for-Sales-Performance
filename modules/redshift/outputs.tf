output "redshift_endpoint" {
  value = aws_redshiftserverless_workgroup.this.endpoint
}

output "redshift_secret_arn" {
  value = aws_secretsmanager_secret.redshift.arn
}

output "redshift_role_arn" {
  value = aws_iam_role.redshift.arn
}


output "security_group_id" {
  description = "ID of the Redshift security group"
  value       = aws_security_group.redshift.id
}

output "namespace_name" {
  description = "Name of the Redshift Serverless namespace"
  value       = aws_redshiftserverless_namespace.this.namespace_name
}

output "workgroup_name" {
  description = "Name of the Redshift Serverless workgroup"
  value       = aws_redshiftserverless_workgroup.this.workgroup_name
}