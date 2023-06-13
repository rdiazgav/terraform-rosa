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
  default     = "kubeadmin"
}

variable "htpasswd_password" {
  type        = string
  description = "htpasswd password"
  sensitive   = true
  default     = "p455w0rd123"
}