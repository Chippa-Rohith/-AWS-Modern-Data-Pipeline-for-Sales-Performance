# --- Random password for Redshift admin ---
resource "random_password" "redshift" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]{}.,?"
}

# --- Secrets Manager for Redshift Serverless ---
resource "aws_secretsmanager_secret" "redshift" {
  name = "${var.project}/redshift-serverless/credentials"
  tags = {
    RedshiftAdminSecret = "true"
  }
}

resource "aws_secretsmanager_secret_version" "redshift" {
  secret_id     = aws_secretsmanager_secret.redshift.id
  secret_string = jsonencode({
    username = var.admin_username
    password = random_password.redshift.result
    engine   = "redshift"
    port     = 5439
    dbname   = var.db_name
  })
}

# --- IAM Role for Redshift Serverless (S3 access) ---
resource "aws_iam_role" "redshift" {
  name = "${var.project}-redshift-serverless-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "redshift.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_readonly" {
  role       = aws_iam_role.redshift.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# --- Optional: S3 Bucket Policy for COPY/UNLOAD ---
resource "aws_s3_bucket_policy" "redshift" {
  bucket = var.s3_bucket
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = aws_iam_role.redshift.arn
      },
      Action = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject"
      ],
      Resource = [
        "arn:aws:s3:::${var.s3_bucket}",
        "arn:aws:s3:::${var.s3_bucket}/*"
      ]
    }]
  })
}

# --- Security Group for Redshift Serverless ---
resource "aws_security_group" "redshift" {
  vpc_id      = var.vpc_id
  name        = "${var.project}-redshift-sg"
  description = "Allow Redshift Serverless access from allowed CIDR"

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-redshift-sg" }
}


# --- Redshift Serverless Namespace ---
resource "aws_redshiftserverless_namespace" "this" {
  namespace_name      = "${var.project}-ns"
  db_name             = var.db_name
  admin_username      = var.admin_username
  admin_user_password = random_password.redshift.result
  iam_roles           = [aws_iam_role.redshift.arn]

  tags = {
    Name = "${var.project}-namespace"
  }
}

# --- Redshift Serverless Workgroup ---
resource "aws_redshiftserverless_workgroup" "this" {
  workgroup_name = "${var.project}-wg"
  namespace_name = aws_redshiftserverless_namespace.this.namespace_name

  base_capacity     = var.base_rpus   # e.g. 8
  max_capacity      = var.max_rpus    # e.g. 32
  publicly_accessible = false

  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.redshift.id]

  tags = {
    Name = "${var.project}-workgroup"
  }
}


# --- Update secret with endpoint ---
resource "aws_secretsmanager_secret_version" "redshift_full" {
  secret_id = aws_secretsmanager_secret.redshift.id
  secret_string = jsonencode({
    username = var.admin_username
    password = random_password.redshift.result
    engine   = "redshift"
    host     = aws_redshiftserverless_workgroup.this.endpoint
    port     = 5439
    dbname   = var.db_name
    iam_role = aws_iam_role.redshift.arn
  })
  depends_on = [aws_redshiftserverless_workgroup.this]
}