resource "aws_ecr_repository" "front_end" {
  name                 = "esgi-cloud-project-front_end"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "front_end" {
  name = "esgi_cloud_front_end"
}

resource "aws_iam_role" "front_end_elastic_container" {
  name = "esgi_cloud_front_end_elastic_container"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "front_end_elastic_container" {
  name = "esgi_cloud_elastic_container"
  role = "${aws_iam_role.front_end_elastic_container.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "${aws_s3_bucket.front_end_code_pipeline.arn}",
        "${aws_s3_bucket.front_end_code_pipeline.arn}/*"
      ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
            "ecr:GetDownloadUrlForLayer",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:CreateLogGroup"
        ],
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "dynamodb:Scan",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:GetItem"
        ],
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage"
        ],
        "Resource": "${var.sqs_arn}"
    }
  ]
}
EOF
}

data "template_file" "front_end_task_definition_ecs" {
  template = "${file("${path.module}/task_definitions_service.json")}"

  vars = {
    app_port = var.app_port 
    image = "${aws_ecr_repository.front_end.repository_url}:latest"
    event_service_url = var.sqs_id
    event_service_arn = var.sqs_arn
  }
}

resource "aws_ecs_task_definition" "front_end" {
  family                = "esgi_cloud_front_end"
  container_definitions = "${data.template_file.front_end_task_definition_ecs.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn = "${aws_iam_role.front_end_elastic_container.arn}"
  task_role_arn = "${aws_iam_role.front_end_elastic_container.arn}"
}

resource "aws_ecs_service" "front_end" {
  name            = "esgi_cloud_front_end"
  cluster         = "${aws_ecs_cluster.front_end.id}"
  task_definition = "${aws_ecs_task_definition.front_end.arn}"
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.front_end_ecs.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.front_end.id
    container_name   = "esgi_cloud_front_end"
    container_port   = var.app_port
  }

  depends_on = [aws_alb_listener.front_end]
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "/ecs/esgi-cloud-front_end"
    tags = {
    Environment = "production"
  }
}

resource "aws_cloudwatch_log_stream" "cb_log_stream" {
  name           = "fargate"
  log_group_name = aws_cloudwatch_log_group.log_group.name
}