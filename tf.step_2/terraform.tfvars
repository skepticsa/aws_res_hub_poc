project                    = "res4"
region                     = "us-east-1"
availability_zones         = ["us-east-1a", "us-east-1b"]
vpc_cidr_block             = "10.0.0.0/16"
public_subnet_cidr_blocks  = ["10.0.0.0/24", "10.0.2.0/24"]
private_subnet_cidr_blocks = ["10.0.1.0/24", "10.0.3.0/24"]
ec2_ami                    = "ami-00c39f71452c08778"
ec2_type                   = "t2.micro"
