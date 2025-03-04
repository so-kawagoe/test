# クラスター
resource "aws_ecs_cluster" "cluster" {
  name = "gpt-api-kawagoe-cluster"

  tags = {
    Name = "gpt-api-kawagoe-cluster"
  }
}

# タスク定義
resource "aws_ecs_task_definition" "gpt_api_kawagoe_task" {
  family                   = "gpt-api-kawagoe-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.gpt_api_kawagoe_role.arn

  container_definitions = jsonencode([
    {
      name  = "aws-gpt-api"
      image = "211125561375.dkr.ecr.ap-northeast-1.amazonaws.com/aws-gpt-api:latest"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# タスク実行ロール
resource "aws_iam_role" "gpt_api_kawagoe_role" {
  name = "gpt-api-kawagoe-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "gpt-api-kawagoe-role"
  }
}

# ECRポリシー
resource "aws_iam_policy" "this" {
  name = "ECRPolicyForECS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
        ],
        Resource = "*"
      },
    ]
  })
}


# タスク実行ロールにAmazonECSTaskExecutionRolePolicyをアタッチ
resource "aws_iam_role_policy_attachment" "this1" {
  role       = aws_iam_role.gpt_api_kawagoe_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# タスク実行ロールにECRポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "this2" {
  role       = aws_iam_role.gpt_api_kawagoe_role.name
  policy_arn = aws_iam_policy.this.arn
}

# サービス
resource "aws_ecs_service" "service" {
  name            = "gpt-api-kawagoe-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.gpt_api_kawagoe_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [
      aws_subnet.gpt_api_kawagoe_public_subnet_1a.id,
      aws_subnet.gpt_api_kawagoe_public_subnet_1c.id
    ]
    security_groups  = [aws_security_group.gpt_api_kawagoe_ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "aws-gpt-api"
    container_port   = 80
  }
}

# セキュリティグループ
resource "aws_security_group" "gpt_api_kawagoe_ecs_sg" {
  vpc_id = aws_vpc.gpt_api_kawagoe.id

  # インバウンド通信（外->中）
  # Type: HTTP, Source: Anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # アウトバウンド通信（中->外）
  # Type: All Traffic, Destination: Anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gpt-api-kawagoe-ecs-sg"
  }
}
