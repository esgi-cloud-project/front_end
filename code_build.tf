resource "aws_iam_role" "front_end_code_build" {
  name = "esgi_cloud_front_end_code_build"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "front_end_code_build" {
  role = "${aws_iam_role.front_end_code_build.name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage"
      ]
    },
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.front_end_code_pipeline.arn}",
        "${aws_s3_bucket.front_end_code_pipeline.arn}/*"
      ]
    }
  ]
}
POLICY
}

data "template_file" "front_end_build_spec_code_build" {
  template = "${file("${path.module}/buildspec.yml")}"

  vars = {
    repository_uri = "${aws_ecr_repository.front_end.repository_url}"
    ecs_task_definitions = "esgi_cloud_front_end"
  }
}

resource "aws_codebuild_project" "front_end" {
  name           = "esgi_cloud_front_end"

  service_role  = "${aws_iam_role.front_end_code_build.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:2.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "${data.template_file.front_end_build_spec_code_build.rendered}"
  }
}