resource "null_resource" "rosa_cli_installer" {
  triggers = {
    aws_region   = var.aws_region
    subnets      = local.subnets
    owner        = var.cluster_owner_tag    
    cluster_name = var.cluster_name
    ocp_version  = var.ocp_version
  }

  provisioner "local-exec" {    
    command = <<EOT
#!/bin/bash

REGION=${self.triggers.aws_region}
SUBNET=${self.triggers.subnets}
OWNER=${self.triggers.owner}
CLUSTER_NAME=${self.triggers.cluster_name}
VERSION=${self.triggers.ocp_version}
ROSA_ENVIRONMENT=Production

rosa create ocm-role --mode auto -y --admin
rosa create user-role --mode auto -y
rosa create account-roles --mode auto -y
time rosa create cluster --region $REGION --version $VERSION --enable-autoscaling --min-replicas 3 --max-replicas 6 --private-link --cluster-name=$CLUSTER_NAME --machine-cidr=${var.cluster_cidr} --subnet-ids=$SUBNET --tags=Owner:$OWNER,Environment:$ROSA_ENVIRONMENT --sts -y --multi-az  || exit 1
sleep 5
rosa create operator-roles --cluster $CLUSTER_NAME -y --mode auto
rosa create oidc-provider --cluster $CLUSTER_NAME -y --mode auto
rosa logs install -c $CLUSTER_NAME --watch
EOT  
  }

  provisioner "local-exec" {
    when   = destroy
    command = <<EOD
echo rosa delete cluster --cluster ${self.triggers.cluster_name} -y
echo rosa logs uninstall -c ${self.triggers.cluster_name} --watch
echo rosa delete operator-roles --cluster ${self.triggers.cluster_name} -y
echo rosa delete oidc-provider --cluster ${self.triggers.cluster_name}  -y
echo rosa delete account-roles -y
echo rosa delete user-role -y
EOD    
  }
  
  depends_on = [ aws_ec2_transit_gateway_vpc_attachment.rosa_vpc_attachment ]
}
