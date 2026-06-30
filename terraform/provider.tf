terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.52.0"
    }
  }
}

provider "aws" {
  region = eu-north-1     # Europe(Stockholm)
  profile = roboticusr    #IAM created 
}