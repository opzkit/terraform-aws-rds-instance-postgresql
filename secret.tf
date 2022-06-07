resource "aws_secretsmanager_secret" "rds_secret" {
  name = "rds/postgres/${var.identifier}"
}

resource "aws_secretsmanager_secret_version" "rds_secret_value" {
  secret_id     = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode(local.secret_value)
}

locals {
  secret_value = {
    DB_USERNAME  = var.master_username
    DB_PASSWORD  = local.password
    DB_NAME      = var.db_name
    DB_PORT      = tostring(aws_db_instance.default.port)
    DB_HOST      = aws_db_instance.default.address
    POSTGRES_URL = "postgres://${var.master_username}:${local.password}@${aws_db_instance.default.address}:${aws_db_instance.default.port}/${var.db_name}?sslmode=disable"

  }
  password = random_password.password.result
}

resource "random_password" "password" {
  length           = 32
  special          = false
  lower            = true
  upper            = true
  numeric          = true
  override_special = ""
  min_special      = 0
  min_lower        = 5
  min_upper        = 5
  min_numeric      = 5
  lifecycle {
    ignore_changes = all
  }
}
