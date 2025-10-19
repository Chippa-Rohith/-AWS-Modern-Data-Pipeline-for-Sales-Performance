# --- S3 bucket for Bronze layer ---
resource "aws_s3_bucket" "sales_pipeline" {
  bucket = "${var.project}-dataengineer-project-bucket"
  force_destroy = true

  tags = {
    Name = "${var.project}-buket"
  }
}

resource "aws_s3_bucket_versioning" "sales_pipeline" {
  bucket = aws_s3_bucket.sales_pipeline.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "dms_role" {
  name = "${var.project}-dms-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "dms.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "dms_s3_access" {
  name = "${var.project}-dms-s3-policy"
  role = aws_iam_role.dms_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [aws_s3_bucket.sales_pipeline.arn]
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = ["${aws_s3_bucket.sales_pipeline.arn}/*"]
      }
    ]
  })
}


# Role for VPC access
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "dms.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role_policy" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# Role for CloudWatch logging
resource "aws_iam_role" "dms_cloudwatch_role" {
  name = "dms-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "dms.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_role_policy" {
  role       = aws_iam_role.dms_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}


# --- DMS Subnet Group (use private subnets where RDS is deployed) ---
resource "aws_dms_replication_subnet_group" "this" {
  replication_subnet_group_id = "${var.project}-dms-subnet-group"
  replication_subnet_group_description = "Subnet group for DMS"
  subnet_ids = var.private_subnet_ids
  tags = { Name = "${var.project}-dms-subnet-group" }
}

# --- DMS Replication Instance ---
resource "aws_dms_replication_instance" "this" {
  replication_instance_id        = "${var.project}-dms-instance"
  replication_instance_class     = "dms.t3.medium"
  allocated_storage              = 50
  vpc_security_group_ids         = [var.rds_sg_id]
  replication_subnet_group_id    = aws_dms_replication_subnet_group.this.id
  publicly_accessible            = false
  apply_immediately              = true
  auto_minor_version_upgrade     = true

  tags = { Name = "${var.project}-dms" }
}

data "aws_secretsmanager_secret_version" "rds" {
  secret_id = var.secret_arn
}

locals {
  rds_creds = jsondecode(data.aws_secretsmanager_secret_version.rds.secret_string)
}


# --- DMS Source Endpoint (RDS MySQL) ---
resource "aws_dms_endpoint" "mysql_source" {
  endpoint_id     = "${var.project}-mysql-source"
  endpoint_type   = "source"
  engine_name     = "mysql"
  username        = local.rds_creds["username"]
  password        = local.rds_creds["password"]
  server_name     = local.rds_creds["host"]
  port            = local.rds_creds["port"]
  database_name   = local.rds_creds["dbname"]
  ssl_mode        = "none"
}

# --- DMS Target Endpoint (S3) ---
resource "aws_dms_endpoint" "s3_target" {
  endpoint_id     = "${var.project}-s3-target"
  endpoint_type   = "target"
  engine_name     = "s3"

  s3_settings {
    bucket_name          = aws_s3_bucket.sales_pipeline.id
    service_access_role_arn = aws_iam_role.dms_role.arn
    bucket_folder        = "bronze-data"
    compression_type     = "GZIP"
    csv_delimiter        = ","
    csv_row_delimiter    = "\n"
    data_format          = "csv"
    # 👇 ensures first row = column headers
    add_column_name = true
    # Required for CDC operations - adds timestamp column for change tracking
    timestamp_column_name   = "dms_timestamp"
    # Optionally include operation column to track INSERT/UPDATE/DELETE operations
    include_op_for_full_load = true
  }
}


# --- DMS Replication Task ---
resource "aws_dms_replication_task" "this" {
  replication_task_id          = "${var.project}-mysql-to-s3"
  migration_type               = "full-load-and-cdc"
  replication_instance_arn     = aws_dms_replication_instance.this.replication_instance_arn
  source_endpoint_arn          = aws_dms_endpoint.mysql_source.endpoint_arn
  target_endpoint_arn          = aws_dms_endpoint.s3_target.endpoint_arn
  table_mappings               = jsonencode({
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "1",
      "object-locator": {
        "schema-name": "salesdb",
        "table-name": "%"
      },
      "rule-action": "include"
    }
  ]
})
  replication_task_settings    = jsonencode({
  "TargetMetadata": {
    "TargetSchema": "",
    "SupportLobs": true,
    "FullLobMode": false,
    "LobChunkSize": 64,
    "LimitedSizeLobMode": true,
    "LobMaxSize": 32
  },
  "FullLoadSettings": {
    "TargetTablePrepMode": "DROP_AND_CREATE",
    "StopTaskCachedChangesApplied": false,
    "StopTaskCachedChangesNotApplied": false,
    "MaxFullLoadSubTasks": 8,
    "TransactionConsistencyTimeout": 600
  },
  "ChangeProcessingSettings": {
      "MemoryLimitTotal": 1024,
      "MemoryKeepTime": 60,
      "StatementCacheSize": 50
    },
  "Logging": {
      "EnableLogging": true,
      "LogComponents": [
        {
          "Id": "SOURCE_UNLOAD",
          "Severity": "LOGGER_SEVERITY_DEFAULT"
        },
        {
          "Id": "TARGET_LOAD",
          "Severity": "LOGGER_SEVERITY_DEFAULT"
        },
        {
          "Id": "TARGET_APPLY",
          "Severity": "LOGGER_SEVERITY_INFO"
        }
      ]
    }
})

  tags = { Name = "${var.project}-replication-task" }
}