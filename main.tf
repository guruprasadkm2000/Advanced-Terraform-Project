terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.52.0"
    }
  }
}
provider "aws" {
  region = "ap-south-1"

}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {} 
  
resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = "ap-south-1a"
  tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
        Name: "${var.env_prefix}-igw"
    }
}

resource "aws_route_table" "myapp-route-table" {
    vpc_id = aws_vpc.myapp-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name: "${var.env_prefix}-rtb"
    }
  
}

resource "aws_route_table_association" "associate-rtb-subnet" {
    subnet_id = aws_subnet.myapp-subnet-1.id
    route_table_id = aws_route_table.myapp-route-table.id
}

resource "aws_security_group" "myapp-sg" {
    name   = "myapp-sg"
    vpc_id = aws_vpc.myapp-vpc.id

    ingress = [
        {
            from_port        = 22
            to_port          = 22
            protocol         = "tcp"
            cidr_blocks      = [var.my_ip]
            description      = "SSH access"
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            security_groups  = []
            self             = false
        },
        {
            from_port        = 8080
            to_port          = 8080
            protocol         = "tcp"
            cidr_blocks      = ["0.0.0.0/0"]
            description      = "HTTP access"
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            security_groups  = []
            self             = false
        },
        {
            from_port        = 80
            to_port          = 80
            protocol         = "tcp"
            cidr_blocks      = ["0.0.0.0/0"]
            description      = "HTTP access"
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            security_groups  = []
            self             = false
        }
    ]

    egress = [
        {
            from_port        = 0
            to_port          = 0
            protocol         = "-1"
            cidr_blocks      = ["0.0.0.0/0"]
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            security_groups  = []
            self             = false
            description      = "Allow all outbound traffic"
        }
    ]

    tags = {
        Name = "${var.env_prefix}-sg"
    }
}

/*data "aws_ami" "latest-amazon-linux-image" {
    most_recent = true
    owners = ["amazon"]
    filter {
      name = "name"
      values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
    filter {
      name   = "root-device-type"
      values = ["ebs"]  # Free Tier eligible AMIs usually use EBS
    }
    filter {
      name = "virtualization-type"
      values = [ "hvm" ]
    }
    filter {
      name   = "architecture"
      values = ["x86_64"]
    }
  
}*/

/*output "aws_ami_id" {
    value = data.aws_ami.latest-amazon-linux-image.id
  
}*/

resource "aws_instance" "myapp-server" {
    ami = "ami-040acbfd65da0c993"
    instance_type = var.instance_type

    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    /*key_name = "aws_keypair.ssh-key.key_name" */
    key_name = "mumbai_keypair"

    /*user_data = file("entry-script.sh") */
    user_data = <<EOF
                    #!/bin/bash
                    sudo yum update -y
                    sudo amazon-linux-extras install docker -y
                    sudo yum install -y docker
                    sudo service docker start
                    sudo docker run hello-world
                    sudo systemctl enable docker
                    sudo usermod -a -G docker ec2-user
                    newgrp docker
                    sudo chmod 666 /var/run/docker.sock
                    sudo systemctl restart docker
                    sudo docker pull nginx
                    sudo docker run --name nginx-container1 -d -p 8080:80 nginx
                EOF

    tags = {
        Name = "${var.env_prefix}-myapp-server"
    }
}
   
