resource "aws_security_group" "webserver" {
  name        = "application"
  description = "Enable access on different ports"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTP Access"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  ingress {
    description = "HTTPS Access"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22 
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }
  ingress {
    description = "Port Access"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "application"
  }
}



resource "aws_security_group" "database" {
  name        = "database"
  description = "Database Security Group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Postgres"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["${aws_security_group.webserver.id}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = ["${aws_security_group.webserver.id}"]
  }
  tags = {
    Name = "database"
  }

}