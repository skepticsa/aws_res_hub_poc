# VPC resources: This will create 1 VPC with 1 Internet Gateway, 2 Public Subnets, 2 Private Subnect, 4 Route Tables. 

resource "aws_vpc" "default" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "${var.project}-igw"
  }
}

# public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "${var.project}-rt-public"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidr_blocks)

  vpc_id                  = aws_vpc.default.id
  cidr_block              = var.public_subnet_cidr_blocks[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-subnet-public-${count.index + 1}"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidr_blocks)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT resources: This will create 2 NAT gateways in 2 Public Subnets for 2 different Private Subnets.
resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidr_blocks)

  vpc = true

  tags = {
    Name = "${var.project}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "default" {
  depends_on = [aws_internet_gateway.default]

  count = length(var.public_subnet_cidr_blocks)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project}-nat-gateway-${count.index + 1}"
  }
}

# private subnets
resource "aws_route" "private" {
  count = length(var.private_subnet_cidr_blocks)

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.default[count.index].id
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidr_blocks)

  vpc_id            = aws_vpc.default.id
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project}-subnet-private-${count.index + 1}"
  }
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidr_blocks)
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "${var.project}-rt-private-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidr_blocks)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC s3 endpoint
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id            = aws_vpc.default.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Interface"
  # security_group_ids  = [aws_security_group.example.id]
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id]
}

# s3 bucket
resource "aws_s3_bucket" "s3bucket" {
  bucket = "${var.project}-s3-5381ef61-0ff3-45f9-b843-f92cb586d4b4"

  tags = {
    Name = "${var.project}-s3"
  }
}

resource "aws_s3_bucket_acl" "s3bucket_acl" {
  bucket = aws_s3_bucket.s3bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "s3bucket_versioning" {
  bucket = aws_s3_bucket.s3bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_backup_vault" "s3_backup_vault" {
  name = "${var.project}-s3-backup-vault"
  # kms_key_arn = aws_kms_key.example.arn

  tags = {
    Name = "${var.project}-s3_backup_vault"
  }
}

resource "aws_backup_plan" "s3bucket_plan" {
  name = "${var.project}-s3-backup-plan"

  rule {
    rule_name         = "${var.project}-rule"
    target_vault_name = aws_backup_vault.s3_backup_vault.name
    schedule          = "cron(0 12 * * ? *)"

    lifecycle {
      cold_storage_after = 90
    }
  }

  tags = {
    Name = "${var.project}-s3bucket_plan"
  }
}

#  EC2
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"
  vpc_id      = aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.myip_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sg"
  }
}

# sg attached to EC2 to allow outgoing connection to RDS
resource "aws_security_group" "ec2_rds" {
  name_prefix = "${var.project}-ec2_rds"
  vpc_id      = aws_vpc.default.id

  tags = {
    Name = "${var.project}-ec2_rds-sg"
  }
}

# EC2 instance
# resource "aws_instance" "ec2_instance" {
#   ami                    = "ami-00c39f71452c08778"
#   instance_type          = "t2.micro"
#   subnet_id              = aws_subnet.public[0].id
#   vpc_security_group_ids = [aws_security_group.allow_ssh.id, aws_security_group.ec2_rds.id]
#   key_name               = "resilience"
#   ebs_block_device {
#     device_name = "/dev/sdh"
#     volume_size = 32
#     volume_type = "gp2"
#   }

#   tags = {
#     Name = "${var.project}-ec2"
#   }
# }


# https://github.com/anandg1/Terraform-AWS-ApplicationLoadBalancer/blob/main/main.tf
resource "aws_security_group" "lb-sg" {
  name        = "${var.project}-lb-sg"
  description = "Allow 80, 443, 22"
  vpc_id      = aws_vpc.default.id

  ingress {
    description = "HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.myip_cidr
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.myip_cidr
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.myip_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project}-lb-sg"
  }
}

resource "aws_lb_target_group" "lb-tg-1" {
  name                          = "${var.project}-lb-tg-1"
  port                          = 80
  protocol                      = "HTTP"
  vpc_id                        = aws_vpc.default.id
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay          = 60

  stickiness {
    enabled         = false
    type            = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project}-lb-tg-1"
  }
}

resource "aws_lb" "app-ln-lb" {
  name                       = "${var.project}-app-ln-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb-sg.id]
  subnets                    = [aws_subnet.public[0].id, aws_subnet.public[1].id]
  enable_deletion_protection = false
  depends_on                 = [aws_lb_target_group.lb-tg-1]

  tags = {
    Name = "${var.project}-app-ln-lb"
  }
}

output "alb-endpoint" {
  value = aws_lb.app-ln-lb.dns_name
}

resource "aws_lb_listener" "lb-listner" {

  load_balancer_arn = aws_lb.app-ln-lb.id
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "*** It is working! ***"
      status_code  = "200"
    }
  }

  depends_on = [aws_lb.app-ln-lb]

  tags = {
    Name = "${var.project}-lb-listner"
  }
}

resource "aws_lb_listener_rule" "rule-1" {

  listener_arn = aws_lb_listener.lb-listner.id
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tg-1.arn
  }

  condition {
    host_header {
      values = ["version1"]
    }
  }

  tags = {
    Name = "${var.project}-rule-1"
  }
}

resource "aws_launch_configuration" "lc-1" {
  image_id        = var.ec2_ami
  instance_type   = var.ec2_type
  security_groups = [aws_security_group.lb-sg.id, aws_security_group.ec2_rds.id]
  user_data       = file("userdata1.sh")
  key_name        = "resilience"
  name_prefix     = "${var.project}-"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg-1" {
  launch_configuration = aws_launch_configuration.lc-1.id
  health_check_type    = "EC2"
  min_size             = 2
  max_size             = 4
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.public[0].id, aws_subnet.public[1].id]
  target_group_arns    = [aws_lb_target_group.lb-tg-1.arn]

  tag {
    key                 = "project"
    value               = var.project
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# sg attached to RDS to allow incoming connection from EC2
resource "aws_security_group" "rds_ec2" {
  name_prefix = "${var.project}-rds_ec2"
  vpc_id      = aws_vpc.default.id

  tags = {
    Name = "${var.project}-rds_ec2-sg"
  }
}

resource "aws_security_group_rule" "egress" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2_rds.id # the EC2 security group to attach to
  source_security_group_id = aws_security_group.rds_ec2.id
}

# RDS
resource "aws_security_group_rule" "ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_ec2.id
  source_security_group_id = aws_security_group.ec2_rds.id # the RDS security group to attach to
}

resource "aws_db_subnet_group" "rds" {
  name = "${var.project}-rds-subnet"
  subnet_ids = [aws_subnet.private[0].id,
  aws_subnet.private[1].id]

  tags = {
    Name = "${var.project}-rds-subnet"
  }
}

resource "aws_db_instance" "rds_instance" {
  identifier                   = "${var.project}-rds"
  engine                       = "postgres"
  instance_class               = "db.t3.micro"
  engine_version               = 15.2
  db_name                      = "${var.project}db"
  allocated_storage            = 32
  username                     = var.username
  password                     = var.password
  multi_az                     = true
  backup_retention_period      = 7
  db_subnet_group_name         = aws_db_subnet_group.rds.name
  vpc_security_group_ids       = [aws_security_group.rds_ec2.id]
  storage_type                 = "gp2"
  performance_insights_enabled = false
  storage_encrypted            = true
  publicly_accessible          = false
  skip_final_snapshot          = true

  tags = {
    Name = "${var.project}-rds"
  }
}


# resource group
resource "aws_resourcegroups_group" "reshub-rg" {
  name = "${var.project}-resource-group"

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "project",
      "Values": ["${var.project}"]
    }
  ]
}
JSON
  }

  tags = {
    Name = "${var.project}-rg"
  }
}


# module "resiliencehub_app" {
#   source = "aws-ia/resiliencehub-app/aws"

#   app_component_name = "rez-app"
#   app_description = "Resilience Hub application"

#   resource_group_name = "${var.project}-resource-group"
# }


# psql -h res1-rds.czmtak5yawpq.us-east-1.rds.amazonaws.com -p 5432 -U dude -d postgres
