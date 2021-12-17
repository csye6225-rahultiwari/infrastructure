// Create VPC
// terraform aws create vpc

locals {
  enable_dns_hostnames = true
  instance_tenancy     = "default"


  map_public_ip_on_launch = true
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  instance_tenancy     = local.instance_tenancy
  enable_dns_hostnames = local.enable_dns_hostnames

  tags = {
    Name = "CSYE6225-VPC"
  }
}

// Create Internet Gateway and Attach it to VPC
// terraform aws create internet gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "IGW-VPC"
  }
}

// Create Public Subnets
// terraform aws create subnet
resource "aws_subnet" "public-subnets" {

  depends_on = [aws_vpc.vpc]
  // for_each = local.subnet_az_cidr
  count                   = length(var.subnet_cidr)
  map_public_ip_on_launch = local.map_public_ip_on_launch
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = element(var.subnet_cidr, count.index)
  availability_zone       = element(data.aws_availability_zones.azs.names, count.index)

  tags = {
    Name = "Subnet ${count.index + 1}"
  }
}

// Create Route Table and Add Public Route
// terraform aws create route table

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = var.route_cidr
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags = {
    Name = "Public Route Table"
  }
}


// Associate Public Subnet to "Public Route Table"
// terraform aws associate subnet with route table

resource "aws_route_table_association" "public-subnets-route-table-association" {
  count          = length(var.subnet_cidr)
  subnet_id      = element(aws_subnet.public-subnets.*.id, count.index)
  route_table_id = aws_route_table.public-route-table.id
}


resource "aws_db_subnet_group" "db-subnet" {
  name       = "test-group-1"
  subnet_ids = aws_subnet.public-subnets.*.id
}


resource "aws_db_parameter_group" "rds" {
  name   = "rds-csye6225-pg"
  family = "postgres13"

  parameter {
    name         = "log_connections"
    value        = 1
    apply_method = "pending-reboot"
  }


}

// Network Interface

resource "aws_network_interface" "my-interface" {

  subnet_id       = element(aws_subnet.public-subnets.*.id, 1)
  security_groups = [aws_security_group.webserver.id]

  tags = {
    Name = "csye6225-Interface"
  }
}



resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"

  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow"
        }
      ]
    }
EOF
}

#Policy

resource "aws_iam_policy" "WebAppS3" {
  name        = "WebAppS3"
  description = "policy for webApp"

  policy = <<EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${var.bucket}",
                "arn:aws:s3:::${var.bucket}/*",
                "arn:aws:s3:::${var.codedeploy_bucket}",
                "arn:aws:s3:::${var.codedeploy_bucket}/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "policy-attach" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = aws_iam_policy.WebAppS3.arn
}


resource "aws_iam_instance_profile" "csye6225_profile" {
  name = "csye6225_profile"
  role = aws_iam_role.EC2-CSYE6225.name
}

resource "aws_launch_configuration" "launch_config" {
  name          = "asg_launch_config"
  image_id      = "${var.ami}"
  instance_type = "t2.micro"
  key_name      = "${var.key_name}"
  associate_public_ip_address = true
  iam_instance_profile    = "${aws_iam_instance_profile.csye6225_profile.name}"
  security_groups  = ["${aws_security_group.webserver.id}"]
  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = "true"
  }
  depends_on = [aws_s3_bucket.csye6225-bucket,aws_db_instance.db]
    user_data               = <<EOF
#!/bin/bash
sudo touch /home/ubuntu/.env
sudo echo "RDS_USERNAME=\"${aws_db_instance.db.username}\"" >> /home/ubuntu/.env
sudo echo "RDS_PASSWORD=\"${aws_db_instance.db.password}\"" >> /home/ubuntu/.env
sudo echo "RDS_HOSTNAME=\"${aws_db_instance.db.address}\"" >> /home/ubuntu/.env
sudo echo "RDS_AWS_BUCKET=\"${aws_s3_bucket.csye6225-bucket.bucket}\"" >> /home/ubuntu/.env
sudo echo "RDS_ENDPOINT=\"${aws_db_instance.db.endpoint}\"" >> /home/ubuntu/.env
sudo echo "RDS_DB_NAME=\"${aws_db_instance.db.name}\"" >> /home/ubuntu/.env
sudo echo "AWS_ACCESS_KEY=\"${var.access_key}\"" >> /home/ubuntu/.env
sudo echo "AWS_SECRET_KEY=\"${var.secret_key}\"" >> /home/ubuntu/.env
sudo echo "AWS_BUCKET_REGION=\"${var.region}\"" >> /home/ubuntu/.env
  EOF

  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_autoscaling_group" "auto_scale_group" {
  name                 = "webapp_auto_scaling_group"
  default_cooldown = 60
  launch_configuration = "${aws_launch_configuration.launch_config.name}"
  min_size             = 3
  max_size             = 5
  desired_capacity     = 3
  vpc_zone_identifier       = [element(aws_subnet.public-subnets.*.id, 1)]

  lifecycle {
    create_before_destroy = true
  }


  tag {
    key                 = "Name"
    value               = "autoscaling-codedeploy"
    propagate_at_launch = true
  }
}


resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "WebServer-ScaleUpPolicy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.auto_scale_group.name}"
}

resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "WebServer-ScaleDownPolicy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.auto_scale_group.name}"
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmRateHigh" {
  alarm_name          = "CPUAlarmHigh"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "5"

  alarm_description = "Scale-up if CPU utilization exceeds"
  alarm_actions     = ["${aws_autoscaling_policy.scale_up_policy.arn}"]

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.auto_scale_group.name}"
  }
}


resource "aws_cloudwatch_metric_alarm" "CPUAlarmRateLow" {
  alarm_name          = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "3"

  alarm_description = "Scale-down if CPU utilization reduces"
  alarm_actions     = ["${aws_autoscaling_policy.scale_down_policy.arn}"]

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.auto_scale_group.name}"
  }
}


resource "aws_cloudwatch_log_group" "csye6225-log-group" {
name = "csye6225"
}

resource "aws_cloudwatch_log_stream""csye6225-stream" {
name = "webapp"
log_group_name = aws_cloudwatch_log_group.csye6225-log-group.name

}


resource "aws_iam_role_policy_attachment" "cloudwatch-ec2-attach" {
  role       = "${aws_iam_role.EC2-CSYE6225.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatchadmin-ec2-attach" {
  role       = "${aws_iam_role.EC2-CSYE6225.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy"
}


resource "aws_lb" "application_load_balancer" {
  name               = "webapp-load-balancer"
  load_balancer_type = "application"
  internal = false
  security_groups    = ["${aws_security_group.lb_securitygroup.id}"]
  subnets            = aws_subnet.public-subnets.*.id
  ip_address_type            = "ipv4"
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "target_group" {
  name     = "webapp-target-group"
  port     = "8080"
  protocol = "HTTP"
  
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    path                = "/healthCheck"
    port                = "8080"
    matcher             = "200"
}  
  vpc_id   = "${aws_vpc.vpc.id}"
 
}

resource "aws_lb_listener" "load_balancer_listener" {
  load_balancer_arn = "${aws_lb.application_load_balancer.arn}"
  port              = "80"
  protocol          = "HTTP"
  // certificate_arn   = "arn:aws:acm:us-east-1:928635526926:certificate/bcd377e2-78f9-4951-82d0-5abc052ace17"
  // ssl_policy        = "ELBSecurityPolicy-2016-08"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
  }
}

resource "aws_autoscaling_attachment" "autoscalinggroup_attachment" {
  autoscaling_group_name = "${aws_autoscaling_group.auto_scale_group.id}"
  alb_target_group_arn   = "${aws_lb_target_group.target_group.arn}"
}

data "aws_route53_zone" "selected" {
  name         = var.domain_name

}



resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = data.aws_route53_zone.selected.name
  type    = "A"
  
  alias {
    name                   = aws_lb.application_load_balancer.dns_name
    zone_id                = aws_lb.application_load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_codedeploy_app" "code_deploy_app" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.code_deploy_service_role.name
}

resource "aws_iam_role" "code_deploy_service_role" {
  name = "CodeDeployServiceRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_codedeploy_deployment_group" "csye6225-webapp-deployment" {
  app_name               = aws_codedeploy_app.code_deploy_app.name
  deployment_group_name  = "csye6225-webapp-deployment"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  service_role_arn       = aws_iam_role.code_deploy_service_role.arn
  
  deployment_style {
    deployment_type   = "IN_PLACE"
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "csye6225-ec2-instance"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  depends_on = [aws_codedeploy_app.code_deploy_app]
  autoscaling_groups     = ["${aws_autoscaling_group.auto_scale_group.name}"]
}

resource "aws_iam_policy" "GH_Upload_To_S3" {
  name   = "gh_upload_to_s3"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                  "s3:Get*",
                  "s3:List*",
                  "s3:PutObject",
                  "s3:DeleteObject",
                  "s3:DeleteObjectVersion"
            ],
            "Resource": [
                "arn:aws:s3:::${var.codedeploy_bucket}",
                "arn:aws:s3:::${var.codedeploy_bucket}/*"
              ]
        }
    ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "ghactions_s3_policy_attach" {
  user       = "ghactions-app"
  policy_arn = aws_iam_policy.GH_Upload_To_S3.arn
}


resource "aws_iam_policy" "GH_Code_Deploy" {
  name   = "GH-Code-Deploy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${local.aws_user_account_id}:application:${aws_codedeploy_app.code_deploy_app.name}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
         "arn:aws:codedeploy:${var.region}:${local.aws_user_account_id}:deploymentgroup:${aws_codedeploy_app.code_deploy_app.name}/${aws_codedeploy_deployment_group.csye6225-webapp-deployment.deployment_group_name}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${local.aws_user_account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
EOF
}


data "aws_caller_identity" "current_user" {}

locals {
  aws_user_account_id = data.aws_caller_identity.current_user.account_id
}

resource "aws_iam_user_policy_attachment" "ghactions_codedeploy_policy_attach" {
  user       = "ghactions-app"
  policy_arn = aws_iam_policy.GH_Code_Deploy.arn
}












