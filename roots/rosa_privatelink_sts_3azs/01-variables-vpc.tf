variable "aws_region" {
    default = "eu-central-1"
    description   = "AWS region where to deploy."
    type = string
}

variable "env_name" {
    default = "rosa-csa-test-rosaenvb"
    description   = "Environment name"
    type = string
}

variable "egress_env_name" {
    default = "rosa-csa-test-egressenvb"
    description   = "Environment name"
    type = string
}

variable "cluster_name" {
    default = "rosa-csa-test"
    description   = "Cluster name"
    type = string
}

variable "ocp_version" {
    default = "4.12.18"
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