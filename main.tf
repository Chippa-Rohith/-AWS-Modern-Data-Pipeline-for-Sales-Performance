module "rds_mysql" {
  source = "./modules/rds_mysql"

  project          = var.project
  region           = var.region
  allowed_cidr     = var.allowed_cidr
  db_instance_class = var.db_instance_class
  key_pair_name = var.key_pair_name
}


module "lambda_fake_data" {
  source            = "./modules/lambda_fake_data"
  project           = var.project
  vpc_id            = module.rds_mysql.vpc_id
  private_subnet_ids = module.rds_mysql.private_subnet_ids
  rds_sg_id         = module.rds_mysql.rds_sg_id
  secret_arn        = module.rds_mysql.secret_arn
  lambda_package    = "./assets/lambda_function/lambda_function.zip"
}


module "dms" {
  source            = "./modules/dms"
  project           = var.project
  private_subnet_ids = module.rds_mysql.private_subnet_ids
  rds_sg_id         = module.rds_mysql.rds_sg_id
  rds_endpoint      = module.rds_mysql.rds_endpoint
  secret_arn        = module.rds_mysql.secret_arn
  region             = var.region
}

module "glue_crawler" {
  source = "./modules/glue_crawler"

  project            = var.project
  glue_database_name = "sales_pipeline_glue_db"
  bronze_s3_path     = "s3://${module.dms.s3_bucket_name}/bronze-data/salesdb"
  bronze_s3_arn  = module.dms.s3_bucket_arn 
  crawler_schedule   = "cron(0 12 * * ? *)"  # optional daily at 12 UTC
  bronze_tables = ["Customer", "Product", "Orders", "orderDetails"]
}

# Retrieve Redshift credentials from Secrets Manager
data "aws_secretsmanager_secret_version" "redshift" {
  secret_id = module.redshift.redshift_secret_arn
}

locals {
  redshift_credentials = jsondecode(data.aws_secretsmanager_secret_version.redshift.secret_string)
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}


module "glue_job" {
  source = "./modules/glue_job"
  project = var.project
  glue_service_role_arn = module.glue_crawler.glue_service_role_arn
  scripts_bucket        = module.dms.s3_bucket_name
  s3_bucket             = module.dms.s3_bucket_name
  glue_database_name    = "sales_pipeline_glue_db"

  # New variables for Redshift connection
  vpc_id                     = module.rds_mysql.vpc_id
  redshift_endpoint          = module.redshift.redshift_endpoint[0].address
  redshift_database         = local.redshift_credentials.dbname
  redshift_username         = local.redshift_credentials.username
  redshift_password         = local.redshift_credentials.password
  redshift_security_group_id = module.redshift.security_group_id  # You'll need this output
  redshift_secret_arn       = module.redshift.redshift_secret_arn
  private_subnet_id         = module.rds_mysql.private_subnet_ids[0]  # Use first subnet
  availability_zone         = data.aws_availability_zones.available.names[0]
}


module "redshift" {
  source             = "./modules/redshift"
  project            = var.project
  vpc_id             = module.rds_mysql.vpc_id
  private_subnet_ids = module.rds_mysql.private_subnet_ids
  allowed_cidr       = var.allowed_cidr
  db_name            = "production"
  s3_bucket          = module.dms.s3_bucket_name
  base_rpus          = 8
  max_rpus           = 32
}


module "step_function" {
  source             = "./modules/step_function_pipeline"
  name               = "sales-pipeline-state-machine"
  redshift_secret_arn = module.redshift.redshift_secret_arn
  workgroup_name      = module.redshift.workgroup_name
}