variable "aws_region" {
    default = "eu-central-1"
    description   = "AWS region where to deploy."
    type = string
}

variable "env_name" {
    default = "lmartinhrosaenvb"
    description   = "Environment name"
    type = string
}

variable "egress_env_name" {
    default = "lmartinhegressenvb"
    description   = "Environment name"
    type = string
}

variable "cluster_name" {
    default = "lmartinh04"
    description   = "Cluster name"
    type = string
}

variable "ocp_version" {
    default = "4.12.14"
    description   = "OCP Version to Install."
    type = string
}

variable "cluster_owner_tag" {
    default = "lmartinh"
    description   = "Cluster owner name to tag resources"
    type = string
}

variable "cluster_cidr" {
    default = "10.1.0.0/16"
    description   = "ROSA VPC CIDR"
}

variable "egress_vpc_cidr" {
    default = "10.0.0.0/16"
    description   = "Egress VPC CIDR"
}

variable "pubkey" {
    default = ""
    description   = "Pubkey to use in any system that requires it."
}


# Using RHEL AMIs https://access.redhat.com/solutions/15356
variable "generic_ami" {
    #default = "ami-0b2a401a8b3f4edd3" # Fedora 34 eu-central-1
    #default = "ami-086c1d77a774201ee" # Fedora 34 us-east-2
    type = map
    default = {
        af-south-1     = "ami-062c4716a546acec9"
        ap-south-1     = "ami-05c8ca4485f8b138a"
        ap-northeast-1 = "ami-0f903fb156f24adbf"
        ap-northeast-2 = "ami-06c568b08b5a431d5"
        ap-northeast-3 = "ami-044921b7897a7e0da"
        ap-southeast-1 = "ami-0fb1ff50b2338a261"
        ap-southeast-2 = "ami-0808460885ff81045"
        ca-central-1   = "ami-0c3d3a230b9668c02"
        eu-central-1   = "ami-0e7e134863fac4946"
        eu-north-1     = "ami-06a2a41d455060f8b"
        eu-west-1      = "ami-0f0f1c02e5e4d9d9f"
        eu-west-2      = "ami-035c5dc086849b5de"
        eu-west-3      = "ami-0460bf124812bebfa"
        sa-east-1      = "ami-0c1b8b886626f940c"
        us-east-1      = "ami-06640050dc3f556bb"
        us-east-2      = "ami-092b43193629811af"
        us-west-1      = "ami-0186e3fec9b0283ee"
        us-west-2      = "ami-0bb199dd39edd7d71"
  }
    description   = "AMI to use in any system that does not belong to the cluster."
}


# following two not in use for now
//variable "cluster_priv_subs" {
//   type = map
//   default = {
//      az-1 = {
//         cidr = "10.1.198.0/24"
//      }
//      az-2 = {
//         cidr = "10.1.199.0/24"
//      }
//      az-3 = {
//         cidr = "10.1.200.0/24"
//      }
//   }
//}

//variable "cluster_pub_subs" {
//  type = map
//   default = {
//      sub-1 = {
//         cidr = "10.1.100.0/24"
//      }
//      sub-2 = {
//         cidr = "10.1.101.0/24"
//      }
//      sub-3 = {
//         cidr = "10.1.102.0/24"
//      }
//   }
//}

# following two not in use for now
//variable "egress-vpc_priv_subs" {
//   type = map
//   default = {
//      az-1 = {
//         cidr = "10.0.101.0/24"
//      }
//      az-2 = {
//         cidr = "10.0.102.0/24"
//      }
//      az-3 = {
//         cidr = "10.0.103.0/24"
//      }
//   }
//}

//variable "egress-vpc_pub_subs" {
//  type = map
//   default = {
//      sub-1 = {
//         cidr = "10.1.110.0/24"
//      }
//      sub-2 = {
//         cidr = "10.1.111.0/24"
//      }
//      sub-3 = {
//         cidr = "10.1.112.0/24"
//      }
//   }
//}

//locals {
//  public_subnets = {
//    "${var.region}a" = "10.10.101.0/24"
//    "${var.region}b" = "10.10.102.0/24"
//    "${var.region}c" = "10.10.103.0/24"
//  }
//  private_subnets = {
//    "${var.region}a" = "10.10.201.0/24"
//    "${var.region}b" = "10.10.202.0/24"
//    "${var.region}c" = "10.10.203.0/24"
//  }
//}
