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

# NAT resources: This will create 1 NAT gateway in 1 Public Subnets for 2 different Private Subnets.

resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidr_blocks)

  vpc = true

  tags = {
    Name = "${var.project}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "default" {
  depends_on = [aws_internet_gateway.default]

  count = length(var.public_subnet_cidr_blocks) - 1 # only one NAT

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
  nat_gateway_id         = aws_nat_gateway.default[0].id
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
  bucket = "${var.project}-s3-6afde6ae-8014-4bf9-b515-eeb36be991df"

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
    status = "Disabled"
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
resource "aws_instance" "ec2_instance" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id, aws_security_group.ec2_rds.id]
  key_name               = "resilience"
  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 32
    volume_type = "gp2"
  }

  tags = {
    Name = "${var.project}-ec2"
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
  allocated_storage            = 16
  username                     = var.username
  password                     = var.password
  multi_az                     = false
  availability_zone            = element(var.availability_zones, 0)
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
