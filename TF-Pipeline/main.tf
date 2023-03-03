# Establish AWS as the provider
provider "aws" {
  region    = "us-east-1"
  profile   = "nabeel.malik"
}

# Use data source to get all avalablility zones in the us-east-1 region
data "aws_availability_zones" "available_zones" {}

# Create a VPC
resource "aws_vpc" "default_vpc" {
  cidr_block              = "10.0.0.0/16"
  enable_dns_support      = true
  enable_dns_hostnames    = true

  tags    = {
    Name  = "default vpc"
  }
}

resource "aws_subnet" "public_subnet" {

  vpc_id                  = aws_vpc.default_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public subnet"
  }

}

resource "aws_subnet" "private_subnet" {

  vpc_id                  = aws_vpc.default_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "private subnet"
  }

}

# Create internet gateway and attach it to the VPC
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.default_vpc.id
}

# Create public route table and route to the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

# Create security group for the EC2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 8080 and 22"
  vpc_id      = aws_vpc.default_vpc.id

  # Allow access on port 8080
  ingress {
    description      = "http proxy access"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Allow access on port 22
  ingress {
    description      = "ssh access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags   = {
    Name = "jenkins server security group"
  }
}


# Use data source to get a registered Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


# Launch the EC2 instance and install Jenkins
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "jenkins_ec2"
  # user_data            = file("install_jenkins.sh")

  tags = {
    Name = "Jenkins server"
  }
}


# An empty resource block to automate an SSH into the EC2 instance
resource "null_resource" "name" {

  # SSH into the EC2 instance 
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/Downloads/jenkins_ec2.pem")
    host        = aws_instance.ec2_instance.public_ip
  }

  # Copy the install_jenkins.sh file into the EC2 instance 
  provisioner "file" {
    source      = "install_jenkins.sh"
    destination = "/tmp/install_jenkins.sh"
  }

  # Set permissions and run the install_jenkins.sh file
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x tmp/install_jenkins.sh",
      "sh tmp/install_jenkins.sh",
    ]
  }

  # Wait for the EC2 instance to be created
  depends_on = [aws_instance.ec2_instance]
}


# Print the URL of the Jenkins server in the terminal
output "website_url" {
  value     = join ("", ["http://", aws_instance.ec2_instance.public_dns, ":", "8080"])
}

# Create security group for ECS tasks
resource "aws_security_group" "ecs_tasks" {
  name = "ecs_tasks"
  description = "Allow HTTP inbound traffic from Jenkins and other ECS tasks"
  vpc_id = aws_vpc.default_vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.ec2_security_group.id]
  }
}

# Create IAM role for ECS tasks
resource "aws_iam_role" "ecs_task" {
  name = "ecs_task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach AmazonS3FullAccess policy to the IAM role
resource "aws_iam_role_policy_attachment" "ecs_task_s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3:iam::aws:policy/AmazonS3FullAccess"
  role = aws_iam_role.ecs_task.name
}

# Create task definition for the Hello World application
resource "aws_ecs_task_definition" "hello_world" {
  # Code here
}

# Create S3 bucket for storing Jenkins logs and Python output
resource "aws_s3_bucket" "jenkins" {
  bucket = "jenkins-example-${random_id.random_id.hex}"
  acl = "private"

  versioning {
    enabled = true
  }
}

# Create policy for the S3 bucket
resource "aws_s3_bucket_policy" "jenkins" {
  # code here
}

# Create Jenkins job to build and deploy the application
resource "jenkins_job" "hello_world" { 
  # code here
}

