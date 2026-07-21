terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.52.0"
    }
  }
  backend "s3" {
    bucket         = "jenkins-tfstate-ostry7"
    key            = "infra/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
    use_lockfile   = true
  }
}

provider "aws" {
  region = "${var.region}" # Europe(Stockholm)
  #profile = "roboticusr" #IAM created 
}