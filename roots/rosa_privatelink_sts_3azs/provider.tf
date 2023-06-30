terraform {
    required_version = ">= 0.12.0"
    required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.20.0"
    }
    ocm = {
      version = "= 1.0.4"
      source  = "terraform-redhat/ocm"
    }
  }
}

provider "aws" {
	region = var.aws_region
	ignore_tags {
        key_prefixes = ["kubernetes.io/"]
    }    
}

provider "ocm" {
  token = var.token
  url   = var.url
}