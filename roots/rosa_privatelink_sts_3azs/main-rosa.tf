locals {  
  sts_roles = {
    role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-Installer-Role",
    support_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-Support-Role",
    instance_iam_roles = {
      master_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-ControlPlane-Role",
      worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-Worker-Role"
    },
    operator_role_prefix = var.cluster_name
  }

  subnets_rosa_priv = [for subnet in aws_subnet.rosa-subnet-priv: subnet.id] 
}

resource "ocm_cluster_rosa_classic" "rosa" {
  name                 = var.cluster_name
  
  cloud_region         = var.aws_region
  aws_account_id       = data.aws_caller_identity.current.account_id   

  replicas             = 3
  availability_zones   = data.aws_availability_zones.azs.names 
  aws_private_link     = true
  aws_subnet_ids       = "${local.subnets_rosa_priv}"
  compute_machine_type = "m5.xlarge"
  multi_az             = true
  version              = "openshift-v${var.ocp_version}" 
  machine_cidr         = aws_vpc.rosa-vpc.cidr_block
  properties           = { rosa_creator_arn = data.aws_caller_identity.current.arn } 
  sts                  = local.sts_roles 
  depends_on           = [ aws_vpc.rosa-vpc ]
}


data "ocm_rosa_operator_roles" "operator_roles" {
  operator_role_prefix = var.cluster_name
}


module "operator_roles" {
  source  = "terraform-redhat/rosa-sts/aws"
  version = "0.0.4"

  create_operator_roles = true
  create_oidc_provider  = true
  create_account_roles  = false

  cluster_id                  = ocm_cluster_rosa_classic.rosa.id
  rh_oidc_provider_thumbprint = ocm_cluster_rosa_classic.rosa.sts.thumbprint
  rh_oidc_provider_url        = ocm_cluster_rosa_classic.rosa.sts.oidc_endpoint_url
  operator_roles_properties   = data.ocm_rosa_operator_roles.operator_roles.operator_iam_roles
}

resource "ocm_cluster_wait" "rosa" {
  cluster = ocm_cluster_rosa_classic.rosa.id
  timeout = 60
}

resource "ocm_identity_provider" "rosa_iam_htpasswd" {
   cluster = ocm_cluster_rosa_classic.rosa.id
   name = "htpasswd"
   htpasswd = {
	username = var.htpasswd_username
   	password = var.htpasswd_password
   }
   depends_on = [
     ocm_cluster_wait.rosa
   ]
}

resource "ocm_group_membership" "htpasswd_admin" {
  cluster = ocm_cluster_rosa_classic.rosa.id
  group   = "cluster-admins"
  user    = var.htpasswd_username
  depends_on = [
    ocm_cluster_wait.rosa
  ]
}