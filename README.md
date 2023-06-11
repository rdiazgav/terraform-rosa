# ROSA w/ private link and STS

The code in this repo will create the necesary AWS resources required to deploy Red Hat OpenShift Service on AWS (ROSA) cluster using private link and Secure Token Service.
It will create the cluster in a 3 AZs.

This Terraform template will deploy a Hub and Spoke architecture, with an egress VPC. For internet access, the trafic will flow towards the egress VPC.
## Resources

### For the ROSA cluster
 * It is a fully private cluster (ROSA only in private subnets).
 * Egress traffic is routed to the TGW.
 * ROSA VPC
 * Public and Private subnets
 * Internet GW
 * EIP
 * NAT GW
 * Routing tables, rules and association for each subnet

### Hub - TGW
 * Attachments to the privete subnetworks

### Egress VPC


### Two Bastion host will be deployed
 * Security group
 * Public key
 * Bastion instance

## Diagram

![Quick Drawing](./images/quick-drawing.jpg)


## Prerequisites

 * The terraform AWS provider will need the user to be [authenticated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)
 * The terraform CLI

## Deploy Environment

1. Clone this repo
```
$ git clone https://github.com/luisevm/terraform-rosa.git
```

2. Go to path
```
cd terraform-rosa/roots/rosa_privatelink_sts_3azs
```

3. Deploy AWS resources
```
terraform init
terraform plan -out "rosa.plan"
terraform apply "rosa.plan"
```

## Deploy Cluster

- Run the script that is displayed in the output of terraform apply command.
- SSH into the bastion host as instructed


