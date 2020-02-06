resource "aws_security_group" "front_end_load_balancer" {
  name        = "esgi_cloud_front_end_load_balancer"
  vpc_id      = var.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "front_end_ecs" {
  name        = "esgi_cloud_front_end_ecs"
  vpc_id      = var.vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = var.app_port
    to_port         = var.app_port
    security_groups = [aws_security_group.front_end_load_balancer.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "front_end" {
  name            = "cb-load-balancer"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.front_end_load_balancer.id]
  depends_on = [var.public_subnet_depends_on]
}

resource "aws_alb_target_group" "front_end" {
  name        = "cb-target-group"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc.id
  target_type = "ip"
  health_check {
    path = "/"
    matcher = "200,404"
  }
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.front_end.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.front_end.arn}"
  }
}

output "alb_hostname" {
  value = aws_alb.front_end.dns_name
}