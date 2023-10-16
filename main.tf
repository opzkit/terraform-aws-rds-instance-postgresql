resource "aws_db_subnet_group" "default" {
  name       = "${var.identifier}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.identifier} DB subnet group"
  }
}

data "aws_security_group" "security_groups" {
  for_each = toset(var.security_group_names)
  name     = each.value
}

resource "aws_security_group" "allow_postgres" {
  vpc_id = var.vpc_id
  name   = "allow-postgresql-${var.identifier}"

  ingress {
    from_port       = 5432
    protocol        = "tcp"
    to_port         = 5432
    security_groups = [for i, g in data.aws_security_group.security_groups : g.id]
  }

  egress {
    from_port       = 0
    protocol        = "-1"
    to_port         = 0
    security_groups = [for i, g in data.aws_security_group.security_groups : g.id]
  }
}

resource "aws_db_parameter_group" "default" {
  family = "postgres13"
  name   = "${var.identifier}-parameters"

  dynamic "parameter" {
    for_each = merge(var.parameters, local.default_parameters)
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }
}

resource "aws_db_instance" "default" {
  instance_class                        = var.instance_type
  engine                                = "postgres"
  engine_version                        = var.postgresql_version
  allocated_storage                     = var.allocated_storage
  max_allocated_storage                 = 60
  skip_final_snapshot                   = var.skip_final_snapshot
  identifier                            = var.identifier
  db_name                               = var.db_name
  username                              = var.master_username
  password                              = local.password
  monitoring_interval                   = var.enhanced_monitoring ? 60 : 0
  monitoring_role_arn                   = var.enhanced_monitoring ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
  maintenance_window                    = "mon:02:00-mon:03:30"
  backup_window                         = "03:30-05:00"
  backup_retention_period               = 14
  allow_major_version_upgrade           = true
  apply_immediately                     = var.apply_immediately
  db_subnet_group_name                  = aws_db_subnet_group.default.name
  storage_encrypted                     = var.storage_encrypted
  vpc_security_group_ids                = [aws_security_group.allow_postgres.id]
  parameter_group_name                  = aws_db_parameter_group.default.name
  kms_key_id                            = var.kms_key_arn
  performance_insights_kms_key_id       = var.kms_key_arn == "" ? null : var.kms_key_arn
  performance_insights_enabled          = true
  performance_insights_retention_period = var.performance_insights_retention_period
  ca_cert_identifier                    = var.ca_cert_identifier
}

locals {
  default_parameters = {
    "pg_stat_statements.save"           = 1
    "pg_stat_statements.track"          = "TOP"
    "pg_stat_statements.track_planning" = 1
  }
}
