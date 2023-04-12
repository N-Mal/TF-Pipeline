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
  user_data            = file("install_jenkins.sh")

  tags = {
    Name = "Jenkins server"
  }
}

/*# Create an ALB target group for the Hello World service
resource "aws_lb_target_group" "hello_world_target_group" {
  name = "hello-world-target-group"
  port = 5000
  protocol = "HTTP"
  
health_check {
  path = "/health"
}

vpc_id = aws_vpc.default_vpc.id
}

# Create an ALB listener for the Hello World service
resource "aws_lb_listener" "hello_world_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port = 80

  default_action {
  type = "forward"
  target_group_arn = aws_lb_target_group.hello_world_target_group.arn
  }
  
}

# Create an ALB
resource "aws_lb" "load_balancer" {
  name = "hello-world-lb"
  internal = false
  load_balancer_type = "application"
  subnets = [aws_subnet.private_subnet.id]
  security_groups = [aws_security_group.alb_sg.id]
}

# Create an ALB security group
resource "aws_security_group" "alb_sg" {
  name_prefix = "alb_sg_"
}

# ALB security groupt rules
resource "aws_security_group_rule" "alb_sg_ingress" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_sg_egress" {
  type = "egress"
  from_port = 0
  to_port = 65535
  protocol = "tcp"
  cidr_blocks = [aws_vpc.default_vpc.cidr_block]
  security_group_id = aws_security_group.alb_sg.id
} */

# Create a security group for the ECS tasks
resource "aws_security_group" "ecs_sg" {
  name_prefix = "ecs_sg_"
  vpc_id      = aws_vpc.default_vpc.id
}

# Allow inbound traffic to the security group from the VPC
resource "aws_security_group_rule" "ecs_sg_ingress" {
  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = [aws_vpc.default_vpc.cidr_block]
  security_group_id = aws_security_group.ecs_sg.id
}

# Create an ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

# Create a task definition for the Hello World Python app
/*resource "aws_ecs_task_definition" "hello_world_task" {
  family                   = "hello-world-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = 256
  memory                   = 512
  container_definitions    = jsonencode([
    {
      name      = "hello-world-container"
      image     = "python:3.8-slim-buster"
      command   = ["python", "HelloWorld.py"]
      essential = true
      mount_points = [
        {
          sourceVolume = "hello-world-volume"
          containerPath = "/TF-Pipeline"
          readOnly = true
        }
      ]
    }
  ])
  volume {
    name = "hello-world-volume"
  }
}

# Create an ECS task execution role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"
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

# Create an ECS task execution role policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

# Create an ECS service that runs the Python app on a Fargate instance
resource "aws_ecs_service" "hello_world_service" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.hello_world_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Define the service's network configuration
  network_configuration {
    subnets          = [aws_subnet.private_subnet.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }*/
  
  /*# Define the service's load balancer configuration
  load_balancer {
    target_group_arn = aws_lb_target_group.hello_world_target_group.arn
    container_name = "hello-world-container"
    container_port = 5000
    }

  # Define the service's deployment configuration
  deployment_controller {
    type = "ECS"
    }
}*/

/*resource "aws_s3_bucket" "tf_bucket" {
  bucket = "n-mal-tf-pipeline-bucket"

  tags = {
    Name        = "TF Pipeline Bucket"
  }
}*/