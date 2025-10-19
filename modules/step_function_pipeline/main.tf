# IAM Role for Step Functions execution
resource "aws_iam_role" "this" {
  name = "${var.name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Glue, Redshift Data API, and Secrets
resource "aws_iam_policy" "this" {
  name        = "${var.name}-policy"
  description = "Permissions for Step Function to run Glue jobs and Redshift Data API"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Glue job permissions
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:GetJob"
        ]
        Resource = "*"
      },
      # Redshift Data API permissions
      {
        Effect = "Allow"
        Action = [
          "redshift-data:ExecuteStatement",
          "redshift-data:DescribeStatement",
          "redshift-data:CancelStatement"
        ]
        Resource = "*"
      },
      # Secrets Manager access for Redshift auth
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.redshift_secret_arn
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

# Step Function definition using templatefile
resource "aws_sfn_state_machine" "this" {
  name     = var.name
  role_arn = aws_iam_role.this.arn

  definition = templatefile("${path.module}/sales-pipeline-stepfunction-definition.json.tpl", {
    redshift_secret_arn = var.redshift_secret_arn
    workgroup_name      = var.workgroup_name
  })
}
