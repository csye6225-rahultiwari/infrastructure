// RDS INSTANCE CREATION


locals {
  allocated_storage     = 20
  max_allocated_storage = 100
  multi_az              = false
  skip_final_snapshot   = true
  storage_encrypted     = true
}

resource "aws_db_instance" "db" {
  allocated_storage      = local.allocated_storage
  max_allocated_storage  = local.max_allocated_storage
  storage_type           = "gp2"
  // endpoint               = aws_db_instance.db.endpoint
  engine                 = var.engine
  engine_version         = var.engine_version
  instance_class         = "db.t3.micro"
  identifier             = "csye6225"
  name                   = var.rds_name
  username               = var.rds_username
  password               = var.rds_password
  multi_az               = local.multi_az
  skip_final_snapshot    = local.skip_final_snapshot
  db_subnet_group_name   = aws_db_subnet_group.db-subnet.name
  vpc_security_group_ids = ["${aws_security_group.database.id}"]
  storage_encrypted      = local.storage_encrypted
  parameter_group_name   = aws_db_parameter_group.rds.name
  depends_on             = [aws_db_parameter_group.rds]
}