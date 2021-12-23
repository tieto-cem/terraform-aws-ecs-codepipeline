variable "pipeline_name" {}

variable "ecs_dev_cluster_name" {}

variable "ecs_dev_service_name" {}

variable "github_user" {}

variable "repo_user" {}

variable "repo_password" {}

variable "github_repository" {}

variable "github_token" {}


variable "github_repository_branch" {
  default = "master"
}

variable "build_spec" {}

variable "codebuild_image" {
  default = "aws/codebuild/docker:17.09.0"
}

variable "create_pipeline" {}


