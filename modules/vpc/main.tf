provider "aws" {
  region                   = var.region
  shared_config_files      = ["/Users/tamojitchakraborty/.aws/config"]
  shared_credentials_files = ["/Users/tamojitchakraborty/.aws/credentials"]
  profile                  = "default"
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.name
    Env  = var.env
  }
}

# This will be used by the public subnets
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name}-igw"
    Env  = var.env
  }
}

# elastic ip for the nat gateway
resource "aws_eip" "nat_eip" {
  # vpc        = true
  depends_on = [aws_internet_gateway.ig]
}

# Nat gateway for the private subnets
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public.*.id, 0)
  depends_on    = [aws_internet_gateway.ig]
  tags = {
    Name = "${var.name}-nat"
    Env  = var.env
  }
}

# Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.public_subnets_cidr)
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.env}-${element(var.availability_zones, count.index)}-public"
    Env  = var.env
  }
}

# Private subnets
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.private_subnets_cidr)
  cidr_block              = element(var.private_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.env}-${element(var.availability_zones, count.index)}-private"
    Env  = var.env
  }
}

# Private subnets route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.name}-private-route-table"
    Environment = var.env
  }
}

# Public subnets route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.name}-public-route-table"
    Environment = var.env
  }
}

# Add route for public route table to internet gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

# Add route for private route table to nat gateway
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Associate the public route table to public subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Associate the public route table to public subnets
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

# Create a default security for the vpc
resource "aws_security_group" "default" {
  name        = "${var.name}-default-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_vpc.vpc]

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }
  tags = {
    Env = var.env
  }
}
resource "aws_security_group" "stnf-alb-sg" {
  name        = var.stnf-alb-sg
  description = "for asllowing traffic to ecs"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_vpc.vpc]

  ingress {
    description = "Allow http to ALB"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow https to ALB"
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Env = var.env
  }
}
# Create an Application Load Balancer
resource "aws_lb" "application" {
  name               = "${var.name}-application-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.stnf-alb-sg.id]
  subnets            = aws_subnet.public.*.id
  tags = {
    Name = "${var.name}-application-lb"
    Env  = var.env
  }

}


# Associate the Application Load Balancer with the public subnets
resource "aws_security_group" "stnf_alb_sg" {
  name        = "${var.name}-alb-sg"
  description = "Allow http to ALB"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_vpc.vpc]

  ingress {
    description = "Allow http to ALB"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow https to ALB"
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Targergroup for the ALB
resource "aws_lb_target_group" "stnf-alb-tg" {
  name       = "${var.name}-alb-tg"
  port       = 80
  protocol   = "HTTP"
  vpc_id     = aws_vpc.vpc.id
  depends_on = [aws_vpc.vpc]
  target_type = "ip"
  
  tags = {
    Name = "${var.name}-alb-tg"
    Env  = var.env
  }
  
  #health_check {
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.application.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stnf-alb-tg.arn
  }
}
resource "aws_iam_role" "stnf_ecs_task_role" {
  name               = "${var.env}-${var.stnf-ecs-roles-name}-task"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    Name = "stnf-ecs-task-role"
    Env  = var.env
  }
}


# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "dev-stnf-ecs-cluster"
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    Name = "ecs_task_execution_role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "dev-stnf-ecs-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.stnf_ecs_task_role.arn
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 3072
  requires_compatibilities = ["FARGATE"]

  container_definitions = <<EOF
[
  {
    "name": "dev-stnf",
    "image": "691117598985.dkr.ecr.us-east-1.amazonaws.com/dev-stnf-images:latest",
    "portMappings": [
      {
        "containerPort": 80,
        "protocol": "tcp"
      }
    ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "/ecs/",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "stnfservice"
                },
                "secretOptions": []
            }
  }
]
EOF
}

# ECS Service
resource "aws_ecs_service" "ecs_service" {
  name            = "dev-stnf-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private.*.id
    security_groups  = [aws_security_group.dev_stnf_lb_ecs_service_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stnf-alb-tg.arn
    container_name   = "dev-stnf"
    container_port   = 80
  }
}
resource "aws_security_group" "dev_stnf_lb_ecs_service_sg" {
  name        = "dev-stnf-lb-ecs-service-sg"
  description = "Security group for load balancer ECS service"

  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    description     = "Allow traffic from the load balancer"
    # security_groups = ["aws_lb.application.security_groups"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "Allow all outbound traffic"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-stnf-lb-ecs-service-sg"
  }
}

