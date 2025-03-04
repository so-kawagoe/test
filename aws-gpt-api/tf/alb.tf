# ロードバランサーの設定
resource "aws_lb" "this" {
  name               = "gpt-api-kawagoe-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.gpt_api_kawagoe_alb_sg.id]
  subnets            = [
    aws_subnet.gpt_api_kawagoe_public_subnet_1a.id,
    aws_subnet.gpt_api_kawagoe_public_subnet_1c.id
  ]

  tags = {
    Name = "gpt-api-kawagoe-lb"
  }
}

# ターゲットグループの設定
resource "aws_lb_target_group" "this" {
  name     = "gpt-api-kawagoe-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.gpt_api_kawagoe.id
  target_type = "ip"

  health_check {
    enabled             = true  # ヘルスチェックを有効にする
    interval            = 30  # 30秒ごとにチェック
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5  # 5秒でタイムアウト
    healthy_threshold   = 3  # 3回連続で正常ならhealthy
    unhealthy_threshold = 3  # 3回連続で異常ならunhealthy
  }

  tags = {
    Name = "gpt-api-kawagoe-tg"
  }
}

# セキュリティグループ
resource "aws_security_group" "gpt_api_kawagoe_alb_sg" {
  name        = "gpt-api-kawagoe-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.gpt_api_kawagoe.id

  # インバウンドルール
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # アウトバウンドルール
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gpt-api-kawagoe-alb-sg"
  }
}

# リスナーの設定
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
