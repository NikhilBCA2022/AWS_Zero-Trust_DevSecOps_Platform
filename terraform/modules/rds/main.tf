resource "aws_db_subnet_group" "this" {
  name        = "${var.name_prefix}-db-subnets"
  description = "Private subnet group for the Zero-Trust platform database"

  subnet_ids = var.database_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-subnets"
  })
}

resource "aws_security_group" "database" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Allow PostgreSQL access only from the approved application security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from the approved application security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_security_group_id]
  }

  egress {
    description = "HTTPS outbound traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-sg"
  })
}

resource "aws_db_instance" "this" {
  identifier = "${var.name_prefix}-postgres"

  engine         = "postgres"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 30
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "appdb"
  username = "appadmin"

  manage_master_user_password = true

  port                   = 5432
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = 7
  auto_minor_version_upgrade = true

  deletion_protection = true
  skip_final_snapshot = false

  final_snapshot_identifier = "${var.name_prefix}-postgres-final"

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-postgres"
    Component = "Database"
  })
}
