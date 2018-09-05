
Terraform ECS Codepipeline module
====================

Terraform module for building and deploying Docker images.


Overview
--------

This module utilizes AWS CodeBuild and CodePipeline to build Docker images from GitHub repository commits, ship built images to ECR and deploy them to ECS.  

Usage
-----

```hcl

data "template_file" "buildspec" {
  template = "${file("${path.module}/buildspec.yml")}"

  vars {
    REPOSITORY_URI      = "my-repository"
    CONTAINER_NAME      = "my-container"
    DOCKERFILE_LOCATION = "docker"
  }
}

module "pipeline" {
  source                   = "github.com/tieto-cem/terraform-aws-ecs-codepipeline?ref=v0.0.1"
  github_user              = "${var.github_user}"
  github_repository        = "${var.github_repository}"
  github_repository_branch = "${var.github_repository_branch}"
  build_spec               = "${data.template_file.buildspec.rendered}"
  codebuild_image          = "aws/codebuild/java:openjdk-8"
  pipeline_name            = "${var.application_name}-${var.container_name}"
  ecs_dev_cluster_name     = "${data.terraform_remote_state.shared.cluster_name}"
  ecs_dev_service_name     = "${module.service.name}"
  create_pipeline          = "${terraform.workspace == "dev" ? true : false}"
}

```
