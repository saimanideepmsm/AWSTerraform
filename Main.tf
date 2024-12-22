provider "aws" {
  region     = "us-west-2"
  access_key = "Access Key"
  secret_key = "Secret Key"
}

#create a VPC
resource "aws_vpc" "myfirstvpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Learning PROD Main VPC"
    Owner = "myfirstvpc"
  }
}

#create IG
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myfirstvpc.id

  tags = {
    #Name = "myfirst"
    Name = "Learning PROD IG"
  }
}

#Create route table
resource "aws_route_table" "Routetable-Main" {
  vpc_id = aws_vpc.myfirstvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Routetable-Main"
  }
}

#Create a Subnet
resource "aws_subnet" "myfirstsubnet" {
  vpc_id     = aws_vpc.myfirstvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "Learning PROD Subnet"
  }
}

#Assign subnet to Route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.myfirstsubnet.id
  route_table_id = aws_route_table.Routetable-Main.id
}

#Create Security group with 22, 80, 443 ports for traffic flow
resource "aws_security_group" "allow_Web" {
  name        = "allow_WebTraffic"
  description = "Allow Web traffic"
  vpc_id      = aws_vpc.myfirstvpc.id

  tags = {
    Name = "allow_Web_SG"
  }
}

#Https port on 443
resource "aws_vpc_security_group_ingress_rule" "HTTPS" {
  security_group_id = aws_security_group.allow_Web.id
  cidr_ipv4         = aws_vpc.myfirstvpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

#Http port on 80
resource "aws_vpc_security_group_ingress_rule" "HTTP" {
  security_group_id = aws_security_group.allow_Web.id
  cidr_ipv4         = aws_vpc.myfirstvpc.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

#Http port on 22
resource "aws_vpc_security_group_ingress_rule" "SSH" {
  security_group_id = aws_security_group.allow_Web.id
  cidr_ipv4         = aws_vpc.myfirstvpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_Web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#create network interface
resource "aws_network_interface" "WebServerNIC" {
  subnet_id       = aws_subnet.myfirstsubnet.id
  private_ips     = ["10.0.2.50"]
  security_groups = [aws_security_group.allow_Web.id]

#   attachment {
#     instance     = aws_instance.test.id
#     device_index = 1
#   }
}

#create Elastic IP
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.WebServerNIC.id
  associate_with_private_ip = "10.0.2.50"
  depends_on  = [aws_internet_gateway.gw,aws_network_interface.WebServerNIC]
}

#Create a ubuntu instance
resource "aws_instance" "Ubuntu-web" {
  ami           = "ami-05d38da78ce859165"
  instance_type = "t3.micro"
  availability_zone = "us-west-2a"
  key_name = "main-key"

  network_interface {
    network_interface_id = aws_network_interface.WebServerNIC.id
    device_index = 0
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                EOF

  tags = {
    Name = "Instance-Ubuntu"
  }
}