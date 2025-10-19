# Upload all Glue job scripts in job_script_files to your scripts bucket
resource "aws_s3_object" "job_scripts" {
  for_each = fileset("${path.module}/job_script_files", "*.py")

  bucket = var.scripts_bucket
  key    = "glue-job-scripts/${each.value}"
  source = "${path.module}/job_script_files/${each.value}"
  etag   = filemd5("${path.module}/job_script_files/${each.value}")
}



resource "aws_glue_job" "customer_etl" {
  name        = "${var.project}-customer-etl-job"
  description = "ETL job to transform raw customer data into Silver layer"
  role_arn    = var.glue_service_role_arn   # Reusing existing role

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.scripts_bucket}/glue-job-scripts/raw_customer_transformation_etl_job.py"
  }

  default_arguments = {
    "--TempDir"                  = "s3://${var.s3_bucket}/glue-temp/"
    "--job-bookmark-option"      = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"           = "true"
    "--enable-spark-ui"          = "true"
    "--spark-event-logs-path"    = "s3://${var.s3_bucket}/spark-history/"
    "--s3_bucket"                = var.s3_bucket
    "--db_name"                  = "salesdb"
    "--table_name"               = "Customer"
    "--glue_database"            = var.glue_database_name
    "--glue_table_name"          = "raw_data_customer"
  }

  max_retries = 1
  glue_version = "4.0"
  worker_type  = "G.1X"
  number_of_workers = 2

  depends_on = [aws_s3_object.job_scripts]
}



resource "aws_glue_job" "orderdetails_etl" {
  name        = "${var.project}-orderdetails-etl-job"
  description = "ETL job to transform raw orderdetails data into Silver layer"
  role_arn    = var.glue_service_role_arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.scripts_bucket}/glue-job-scripts/raw_orderdetails_transformation_etl_job.py"
  }

  default_arguments = {
    "--TempDir"                  = "s3://${var.s3_bucket}/glue-temp/"
    "--job-bookmark-option"      = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"           = "true"
    "--enable-spark-ui"          = "true"
    "--spark-event-logs-path"    = "s3://${var.s3_bucket}/spark-history/"
    "--s3_bucket"                = var.s3_bucket
    "--db_name"                  = "salesdb"
    "--table_name"               = "orderDetails"
    "--glue_database"            = var.glue_database_name
    "--glue_table_name"          = "raw_data_orderdetails"
  }

  max_retries = 1
  glue_version = "4.0"
  worker_type  = "G.1X"
  number_of_workers = 2

  depends_on = [aws_s3_object.job_scripts]
}




resource "aws_glue_job" "orders_etl" {
  name        = "${var.project}-orders-etl-job"
  description = "ETL job to transform raw orders data into Silver layer"
  role_arn    = var.glue_service_role_arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.scripts_bucket}/glue-job-scripts/raw_orders_transformation_etl_job.py"
  }

  default_arguments = {
    "--TempDir"                  = "s3://${var.s3_bucket}/glue-temp/"
    "--job-bookmark-option"      = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"           = "true"
    "--enable-spark-ui"          = "true"
    "--spark-event-logs-path"    = "s3://${var.s3_bucket}/spark-history/"
    "--s3_bucket"                = var.s3_bucket
    "--db_name"                  = "salesdb"
    "--table_name"               = "Orders"
    "--glue_database"            = var.glue_database_name
    "--glue_table_name"          = "raw_data_orders"
  }

  max_retries = 1
  glue_version = "4.0"
  worker_type  = "G.1X"
  number_of_workers = 2

  depends_on = [aws_s3_object.job_scripts]
}





resource "aws_glue_job" "product_etl" {
  name        = "${var.project}-product-etl-job"
  description = "ETL job to transform raw product data into Silver layer"
  role_arn    = var.glue_service_role_arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.scripts_bucket}/glue-job-scripts/raw_product_transformation_etl_job.py"
  }

  default_arguments = {
    "--TempDir"                  = "s3://${var.s3_bucket}/glue-temp/"
    "--job-bookmark-option"      = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"           = "true"
    "--enable-spark-ui"          = "true"
    "--spark-event-logs-path"    = "s3://${var.s3_bucket}/spark-history/"
    "--s3_bucket"                = var.s3_bucket
    "--db_name"                  = "salesdb"
    "--table_name"               = "Product"
    "--glue_database"            = var.glue_database_name
    "--glue_table_name"          = "raw_data_product"
  }

  max_retries = 1
  glue_version = "4.0"
  worker_type  = "G.1X"
  number_of_workers = 2

  depends_on = [aws_s3_object.job_scripts]
}




# IAM Role specifically for Glue jobs that load data to Redshift
resource "aws_iam_role" "glue_redshift_role" {
  name = "${var.project}-glue-redshift-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project}-glue-redshift-role"
  }
}

# Attach the basic Glue service policy
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_redshift_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom policy for S3 access
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.project}-glue-s3-access"
  role = aws_iam_role.glue_redshift_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}",
          "arn:aws:s3:::${var.s3_bucket}/*",
        ]
      }
    ]
  })
}

# Custom policy for Redshift Serverless access
resource "aws_iam_role_policy" "glue_redshift_access" {
  name = "${var.project}-glue-redshift-access"
  role = aws_iam_role.glue_redshift_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "redshift-serverless:GetCredentials",
          "redshift-serverless:GetWorkgroup",
          "redshift-serverless:GetNamespace",
          "redshift-serverless:ListWorkgroups",
          "redshift-serverless:ListNamespaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.redshift_secret_arn,
          "${var.redshift_secret_arn}*"
        ]
      }
    ]
  })
}

# Custom policy for VPC/Network access (needed for Glue connections)
resource "aws_iam_role_policy" "glue_network_access" {
  name = "${var.project}-glue-network-access"
  role = aws_iam_role.glue_redshift_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute"
        ]
        Resource = "*"
      }
    ]
  })
}

# Custom policy for Glue Catalog access
resource "aws_iam_role_policy" "glue_catalog_access" {
  name = "${var.project}-glue-catalog-access"
  role = aws_iam_role.glue_redshift_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:GetConnection",
          "glue:GetConnections"
        ]
        Resource = "*"
      }
    ]
  })
}

# Custom policy for CloudWatch logs
resource "aws_iam_role_policy" "glue_logs_access" {
  name = "${var.project}-glue-logs-access"
  role = aws_iam_role.glue_redshift_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws-glue/*"
      }
    ]
  })
}

# === SECURITY GROUPS ===

# Security Group specifically for Glue connections
resource "aws_security_group" "glue_connection" {
  name_prefix = "${var.project}-glue-connection-"
  vpc_id      = var.vpc_id
  description = "Security group for Glue connection to Redshift"

  # REQUIRED: Self-referencing rule - allows all traffic within the same security group
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Allow all traffic from same security group (required for Glue)"
  }

  # REQUIRED: Glue needs unrestricted outbound access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic (Glue requirement)"
  }

  tags = {
    Name = "${var.project}-glue-connection-sg"
    Purpose = "Glue connection to Redshift"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Add rule to existing Redshift security group to allow access from Glue
resource "aws_security_group_rule" "redshift_from_glue" {
  type                     = "ingress"
  from_port               = 5439
  to_port                 = 5439
  protocol                = "tcp"
  source_security_group_id = aws_security_group.glue_connection.id
  security_group_id       = var.redshift_security_group_id
  description             = "Allow Glue connection access to Redshift"
}

# === GLUE CONNECTION ===

# Glue Connection for Redshift
resource "aws_glue_connection" "redshift" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${var.redshift_endpoint}:5439/${var.redshift_database}"
    USERNAME            = var.redshift_username
    PASSWORD            = var.redshift_password
  }

  name = "${var.project}-redshift-connection"

  physical_connection_requirements {
    availability_zone      = var.availability_zone
    security_group_id_list = [aws_security_group.glue_connection.id]
    subnet_id             = var.private_subnet_id
  }

  tags = {
    Name = "${var.project}-redshift-connection"
    Purpose = "Glue to Redshift connection"
  }

  depends_on = [
    aws_security_group.glue_connection,
    aws_security_group_rule.redshift_from_glue
  ]
}


# Glue job to load customer data to Redshift
resource "aws_glue_job" "customer_to_redshift" {
  name        = "${var.project}-customer-to-redshift-job"
  description = "Load silver layer customer data into Redshift stage table"
  role_arn    = aws_iam_role.glue_redshift_role.arn  # Using the new dedicated role

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.scripts_bucket}/glue-job-scripts/load_customer_data_to_redshift_job.py"
  }

  default_arguments = {
    "--TempDir"                    = "s3://${var.s3_bucket}/glue-temp/"
    "--job-bookmark-option"        = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"             = "true"
    "--enable-spark-ui"            = "true"
    "--spark-event-logs-path"      = "s3://${var.s3_bucket}/spark-history/"
    "--s3_bucket"                  = var.s3_bucket
    "--silver_database"              = "salesdb"
    "--silver_table_name"          = "Customer"
    "--redshift_connection_name"   = aws_glue_connection.redshift.name
    "--redshift_temp_dir"          = "s3://${var.s3_bucket}/redshift-temp/"
    "--target_schema"              = "sales"
    "--target_table"               = "stage_dim_customer"
  }

  connections = [aws_glue_connection.redshift.name]
  
  max_retries = 1
  glue_version = "4.0"
  worker_type  = "G.1X"
  number_of_workers = 2

  depends_on = [aws_s3_object.job_scripts, aws_glue_connection.redshift]
}



# Glue job to load product data to Redshift
resource "aws_glue_job" "product_to_redshift" {
  name        = "${var.project}-product-to-redshift-job"
  description = "Load silver layer product data into Redshift stage table"
  role_arn    = aws_iam_role.glue_redshift_role.arn  # Using the new dedicated role

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.scripts_bucket}/glue-job-scripts/load_product_data_to_redshift_job.py"
  }

  default_arguments = {
    "--TempDir"                    = "s3://${var.s3_bucket}/glue-temp/"
    "--job-bookmark-option"        = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"             = "true"
    "--enable-spark-ui"            = "true"
    "--spark-event-logs-path"      = "s3://${var.s3_bucket}/spark-history/"
    "--s3_bucket"                  = var.s3_bucket
    "--silver_database"              = "salesdb"
    "--silver_table_name"          = "Product"
    "--redshift_connection_name"   = aws_glue_connection.redshift.name
    "--redshift_temp_dir"          = "s3://${var.s3_bucket}/redshift-temp/"
    "--target_schema"              = "sales"
    "--target_table"               = "stage_dim_product"
  }

  connections = [aws_glue_connection.redshift.name]
  
  max_retries = 1
  glue_version = "4.0"
  worker_type  = "G.1X"
  number_of_workers = 2

  depends_on = [aws_s3_object.job_scripts, aws_glue_connection.redshift]
}




# Glue job to load orders data to Redshift
resource "aws_glue_job" "orders_to_redshift" {
  name        = "${var.project}-orders-to-redshift-job"
  description = "Load silver layer orders data into Redshift stage table"
  role_arn    = aws_iam_role.glue_redshift_role.arn  # Using the new dedicated role

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.scripts_bucket}/glue-job-scripts/load_order_data_to_redshift_job.py"
  }

  default_arguments = {
    "--TempDir"                    = "s3://${var.s3_bucket}/glue-temp/"
    "--job-bookmark-option"        = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"             = "true"
    "--enable-spark-ui"            = "true"
    "--spark-event-logs-path"      = "s3://${var.s3_bucket}/spark-history/"
    "--s3_bucket"                  = var.s3_bucket
    "--silver_database"              = "salesdb"
    "--silver_table_name"          = "Orders"
    "--redshift_connection_name"   = aws_glue_connection.redshift.name
    "--redshift_temp_dir"          = "s3://${var.s3_bucket}/redshift-temp/"
    "--target_schema"              = "sales"
    "--target_table"               = "fact_orders"
  }

  connections = [aws_glue_connection.redshift.name]
  
  max_retries = 1
  glue_version = "4.0"
  worker_type  = "G.1X"
  number_of_workers = 2

  depends_on = [aws_s3_object.job_scripts, aws_glue_connection.redshift]
}





# Glue job to load orderdetails data to Redshift
resource "aws_glue_job" "orderdetails_to_redshift" {
  name        = "${var.project}-orderdetails-to-redshift-job"
  description = "Load silver layer orderdetails data into Redshift stage table"
  role_arn    = aws_iam_role.glue_redshift_role.arn  # Using the new dedicated role

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.scripts_bucket}/glue-job-scripts/load_orderdetails_data_to_redshift_job.py"
  }

  default_arguments = {
    "--TempDir"                    = "s3://${var.s3_bucket}/glue-temp/"
    "--job-bookmark-option"        = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"             = "true"
    "--enable-spark-ui"            = "true"
    "--spark-event-logs-path"      = "s3://${var.s3_bucket}/spark-history/"
    "--s3_bucket"                  = var.s3_bucket
    "--silver_database"              = "salesdb"
    "--silver_table_name"          = "orderDetails"
    "--redshift_connection_name"   = aws_glue_connection.redshift.name
    "--redshift_temp_dir"          = "s3://${var.s3_bucket}/redshift-temp/"
    "--target_schema"              = "sales"
    "--target_table"               = "fact_order_details"
  }

  connections = [aws_glue_connection.redshift.name]
  
  max_retries = 1
  glue_version = "4.0"
  worker_type  = "G.1X"
  number_of_workers = 2

  depends_on = [aws_s3_object.job_scripts, aws_glue_connection.redshift]
}
