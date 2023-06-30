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

variable "token" {
  type      = string
  sensitive = true  
}

variable "url" {
  type      = string
  default   = "https://api.openshift.com"
}

variable "htpasswd_username" {
  type        = string
  description = "htpasswd username"
  default     = "clusteradmin"
}

variable "htpasswd_password" {
  type        = string
  description = "htpasswd password"
  sensitive   = true
}

variable "account_role_prefix" {
  type        = string
  default     = "ibericos"
}

variable "ocm_environment" {
  type        = string
  default     = "production"
}
  