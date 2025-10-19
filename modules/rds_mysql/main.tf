data "aws_availability_zones" "available" {}

# Get the latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# --- VPC ---
resource "aws_vpc" "this" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project}-igw" }
}

# --- Public Subnets ---
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.30.101.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.30.102.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project}-public-b" }
}

# --- Private Subnets ---
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.30.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "${var.project}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.30.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "${var.project}-private-b" }
}

# --- NAT Gateway ---
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = { Name = "${var.project}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags = { Name = "${var.project}-nat" }
  depends_on = [aws_internet_gateway.igw]
}

# --- Route Tables ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = { Name = "${var.project}-private-rt" }
}

# --- Route Table Associations ---
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# --- Bastion Host Security Group ---
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project}-bastion-"
  vpc_id      = aws_vpc.this.id
  description = "Security group for bastion host"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-bastion-sg" }
}

# --- RDS Security Group ---
resource "aws_security_group" "rds" {
  vpc_id      = aws_vpc.this.id
  name        = "${var.project}-rds-sg"
  description = "Allow MySQL from bastion and allowed CIDR"

  ingress {
    description     = "MySQL from bastion"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "MySQL from allowed CIDR"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-rds-sg" }
}

# --- DB subnet group (private subnets only) ---
resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
  tags = { Name = "${var.project}-db-subnet-group" }
}

# --- Bastion Host ---
resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.key_pair_name # You'll need to add this variable

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y mysql
  EOF

  tags = { Name = "${var.project}-bastion" }
}

# --- Password + Secrets Manager ---
resource "random_password" "rds" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]{}.,?"
}

resource "aws_secretsmanager_secret" "rds" {
  name = "${var.project}/rds-mysql/credentials"
}

resource "aws_secretsmanager_secret_version" "rds_basic" {
  secret_id     = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.db_username,
    password = random_password.rds.result,
    engine   = "mysql",
    port     = 3306,
    dbname   = var.db_name
  })
}

# --- DB Parameter Group ---
resource "aws_db_parameter_group" "mysql" {
  name        = "${var.project}-mysql-params"
  family      = "mysql8.0"
  description = "Custom parameter group for MySQL with ROW binlog"

  parameter {
    name  = "binlog_format"
    value = "ROW"
  }
}

# --- RDS ---
resource "aws_db_instance" "mysql" {
  identifier              = "${var.project}-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.db_instance_class
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  allocated_storage       = 20
  max_allocated_storage   = 200
  storage_type            = "gp3"

  db_name                 = var.db_name
  username                = var.db_username
  password                = random_password.rds.result

  multi_az                = false
  publicly_accessible     = false  # Private RDS
  backup_retention_period = 7
  apply_immediately       = true

  skip_final_snapshot     = true

  # 🔑 Attach custom parameter group
  parameter_group_name    = aws_db_parameter_group.mysql.name

  tags = { Name = "${var.project}-mysql" }
}

# --- Update secret with endpoint ---
resource "aws_secretsmanager_secret_version" "rds_full" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.db_username,
    password = random_password.rds.result,
    engine   = "mysql",
    host     = aws_db_instance.mysql.address,
    port     = 3306,
    dbname   = var.db_name
  })
  depends_on = [aws_db_instance.mysql]
}