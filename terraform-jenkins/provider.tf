terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.52.0"
    }
  }
  backend "s3" {
    bucket         = "jenkins-tfstate-ostry7"
    key            = "jenkins/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-north-1" # Europe(Stockholm)
  #profile = "roboticusr" #IAM created 
}