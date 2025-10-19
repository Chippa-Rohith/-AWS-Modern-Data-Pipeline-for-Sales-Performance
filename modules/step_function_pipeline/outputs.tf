output "state_machine_arn" {
  description = "ARN of the Step Function"
  value       = aws_sfn_state_machine.this.arn
}

output "execution_role_arn" {
  description = "ARN of the IAM execution role for Step Function"
  value       = aws_iam_role.this.arn
}
