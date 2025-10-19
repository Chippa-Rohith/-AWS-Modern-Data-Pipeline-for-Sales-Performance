resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Allow Lambda to read RDS credentials from Secrets Manager
resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# --- Lambda Security Group ---
resource "aws_security_group" "lambda" {
  name        = "${var.project}-lambda-sg"
  vpc_id      = var.vpc_id
  description = "Lambda SG to access RDS"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-lambda-sg" }
}

# Allow Lambda SG to connect to RDS
resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = var.rds_sg_id
  source_security_group_id = aws_security_group.lambda.id
}

# --- Lambda Function ---
resource "aws_lambda_function" "fake_data" {
  function_name = "${var.project}-fake-data"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = var.lambda_package
  source_code_hash = filebase64sha256(var.lambda_package)

  timeout = 60
  memory_size = 512

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SECRET_ARN = var.secret_arn
      REGION_NAME="us-east-2"
    }
  }
}

# --- EventBridge Scheduler IAM Role ---
resource "aws_iam_role" "scheduler_role" {
  name = "${var.project}-scheduler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_lambda_invoke" {
  name = "${var.project}-scheduler-lambda-policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "lambda:InvokeFunction"
      ]
      Resource = aws_lambda_function.fake_data.arn
    }]
  })
}

# --- EventBridge Scheduler ---
resource "aws_scheduler_schedule" "lambda_schedule" {
  name        = "${var.project}-lambda-schedule"
  description = "Trigger Lambda every 10 minutes from Sep 29-oct 2, 2025"
  
  # Every 2 hours
  schedule_expression = "rate(10 minutes)"
  
  # Schedule time window: Sep 29, 2025 00:00 UTC to oct 2, 2025 23:59 UTC
  start_date = "2025-09-29T00:00:00Z"
  end_date   = "2025-10-02T23:59:59Z"
  
  # Timezone (optional, defaults to UTC)
  schedule_expression_timezone = "UTC"
  
  state = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.fake_data.arn
    role_arn = aws_iam_role.scheduler_role.arn
  }
}