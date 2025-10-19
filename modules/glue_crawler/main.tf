resource "aws_iam_role" "glue_service_role" {
  name = "${var.project}-glue-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Add S3 read permissions so crawler can actually read your data
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.project}-glue-s3-access"
  role = aws_iam_role.glue_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          var.bronze_s3_arn,             # bucket itself
          "${var.bronze_s3_arn}/*"       # objects inside bucket
        ]
      }
    ]
  })
}


resource "aws_glue_crawler" "bronze_crawler" {
  name         = "${var.project}-bronze-crawler"
  database_name = var.glue_database_name
  role         = aws_iam_role.glue_service_role.arn
  description  = "Crawler for Bronze layer S3 data"

  dynamic "s3_target" {
    for_each = var.bronze_tables
    content {
      path = "${var.bronze_s3_path}/${s3_target.value}"

    }
  }


  # Optional, you can automatically add new tables
  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  # Optional: add prefix so Glue tables are easy to identify
  table_prefix = "raw_data_"

  depends_on = [
    aws_iam_role_policy_attachment.glue_service_policy,
    aws_iam_role_policy.glue_s3_access
  ]
}
