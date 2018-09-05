
resource "aws_s3_bucket" "pipeline_artifact_bucket" {
  count         = "${var.create_pipeline ? 1 : 0}"
  bucket        = "${var.pipeline_name}-bucket"
  acl           = "private"
  force_destroy = true
}

resource "aws_iam_role" "pipeline_role" {
  count              = "${var.create_pipeline ? 1 : 0}"
  name               = "${var.pipeline_name}-pipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "pipeline_policy" {
  count  = "${var.create_pipeline ? 1 : 0}"
  name   = "${var.pipeline_name}-policy"
  role   = "${aws_iam_role.pipeline_role.id}"
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
        "${aws_s3_bucket.pipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.pipeline_artifact_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.pipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.pipeline_artifact_bucket.arn}/*"
      ]
    },
    {
      "Action": [
          "ecs:*",
          "iam:PassRole"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "codebuild_role" {
  count              = "${var.create_pipeline ? 1 : 0}"
  name               = "${var.pipeline_name}-codebuild-role"

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

resource "aws_iam_policy" "codebuild_policy" {
  count       = "${var.create_pipeline ? 1 : 0}"
  name        = "${var.pipeline_name}-codebuild-policy"
  path        = "/service-role/"
  description = "Policy used in trust relationship with CodeBuild"

  policy      = <<POLICY
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
        "logs:PutLogEvents"
      ]
    },
    {
      "Sid": "S3GetObjectPolicy",
      "Effect": "Allow",
      "Action": [
        "s3:ListObjects",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "${aws_s3_bucket.pipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.pipeline_artifact_bucket.arn}/*"
      ]
    },
    {
      "Sid": "S3PutObjectPolicy",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.pipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.pipeline_artifact_bucket.arn}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "codebuild_policy_attachment" {
  count      = "${var.create_pipeline ? 1 : 0}"
  name       = "${var.pipeline_name}-codebuild-policy-attachment"
  policy_arn = "${aws_iam_policy.codebuild_policy.arn}"
  roles      = ["${aws_iam_role.codebuild_role.id}"]
}

resource "aws_iam_role_policy_attachment" "ecr_power_user_policy_attachment" {
  count      = "${var.create_pipeline ? 1 : 0}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = "${aws_iam_role.codebuild_role.name}"
}

resource "aws_codebuild_project" "codebuild_project" {
  count          = "${var.create_pipeline ? 1 : 0}"
  name           = "${var.pipeline_name}-codebuild"
  service_role   = "${aws_iam_role.codebuild_role.arn}"

  source {
    type      = "CODEPIPELINE"
    buildspec = "${var.build_spec}"
  }

  artifacts {
    type      = "CODEPIPELINE"
    packaging = "NONE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "${var.codebuild_image}"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

  }
}

resource "aws_codepipeline" "pipeline" {
  count    = "${var.create_pipeline ? 1 : 0}"
  name     = "${var.pipeline_name}"
  role_arn = "${aws_iam_role.pipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.pipeline_artifact_bucket.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["app-sources"]

      configuration {
        Owner      = "${var.github_user}"
        Repo       = "${var.github_repository}"
        Branch     = "${var.github_repository_branch}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["app-sources"]
      output_artifacts = ["app-build"]
      version          = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.codebuild_project.name}"
      }
    }
  }

  stage {

    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["app-build"]
      version         = "1"

      configuration {
        ClusterName = "${var.ecs_dev_cluster_name}"
        ServiceName = "${var.ecs_dev_service_name}"
        FileName    = "imagedefinitions.json"
      }
    }
  }
}



