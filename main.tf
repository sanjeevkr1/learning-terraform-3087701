# create an EC2 instance with a tomcat AMI such that it can be accessed over internet(http/https)
# and no restriction on outbound traffic
# steps: 
#   1. create a VPC or use the default VPC
#   2. create a security group with the required inbound and outbound rules
#   3. attach the security group with the VPC
#   4. create an EC2 instance with the required AMI and attach it to the VPC- security group
data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

# configure a VPC resource
resource "aws_vpc" "my_vpc_web" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "tf-example"
  }
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc_web.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "tf-example"
  }
}

resource "aws_network_interface" "net_interface" {
  subnet_id   = aws_subnet.my_subnet.id
  #private_ips = ["172.16.10.100"]
  security_groups = [aws_security_group.my_sg_web_allow_http_https_in_allow_all_out.id]
  tags = {
    Name = "primary_network_interface"
  }
}

#resource "aws_default_vpc" "default" {
#  tags = {
#    Name = "Default VPC"
#  }
#}


# configure a security group resource with rules
resource "aws_security_group" "my_sg_web_allow_http_https_in_allow_all_out" {
  name        = "allow_http_https_in_allow_all_outallow_tls"
  description = "Allow all http and https in and allow all out"
  vpc_id      = aws_vpc.my_vpc_web.id

  ingress {
    description      = "allow all HTTPS calls in"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.my_vpc_web.cidr_block]
    #ipv6_cidr_blocks = [aws_vpc.my_vpc_web.ipv6_cidr_block]
  }

  egress {
    description      = "allow all outbound calls"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

# configure a seaparate SG rule resource and attach it with the existing SG
resource "aws_security_group_rule" "my_sg_rule_web_allow_all_http_in" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = [aws_vpc.my_vpc_web.cidr_block]
  security_group_id = aws_security_group.my_sg_web_allow_http_https_in_allow_all_out.id
}


# configure an EC2 instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.app_ami.id
  #instance_type = "t3.nano"
  instance_type= var.instance_type
  #associate_public_ip_address = true
  tags = {
    Name = "HelloWorld"
  }
  network_interface {
    network_interface_id = aws_network_interface.net_interface.id
    device_index         = 0
  }
 # https://stackoverflow.com/questions/57279090/error-network-interface-conflicts-with-vpc-security-group-ids
 # 
 # vpc_security_group_ids = [aws_security_group.my_sg_web_allow_http_https_in_allow_all_out.id]
}

output "instance_public_ips" {
  value = aws_instance.web.public_ip
}