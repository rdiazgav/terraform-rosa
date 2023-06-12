data "aws_caller_identity" "current" {}

data "aws_availability_zones" "azs" {
    state = "available"
    filter {
        name   = "region-name"
        values = [var.aws_region]
    }
}

#used in the Bastion egress/internet, to configure the bastion in the egress_vpc subnet_public
locals {
   subnets_egress_pub = [for subnet in aws_subnet.egress-subnet-pub: subnet.id]
}

#used in the Bastion rosa, to configure the bastion in the rosa_public subnet_public
locals {
   subnets_rosa_pub = [for subnet in aws_subnet.rosa-subnet-pub: subnet.id]
}

resource "aws_vpc" "rosa-vpc" {
    cidr_block           = "${var.cluster_cidr}"
    enable_dns_support   = "true"
    enable_dns_hostnames = "true"
    instance_tenancy     = "default"
    tags = {
        Owner = var.cluster_owner_tag
        Name  = "${var.env_name}-vpc"
    }
}

resource "aws_subnet" "rosa-subnet-priv" {
    for_each                = toset(data.aws_availability_zones.azs.names)
    depends_on              = [aws_vpc.rosa-vpc]
    vpc_id                  = aws_vpc.rosa-vpc.id
    cidr_block              = "10.1.1${index(data.aws_availability_zones.azs.names, each.value) + 1}.0/24"
    map_public_ip_on_launch = "false"
    availability_zone       = each.value
    tags = {
        Owner = var.cluster_owner_tag
        Name  = "${var.env_name}-subnet-priv-${each.key}"
    }
}

resource "aws_subnet" "rosa-subnet-pub" {
    for_each                = toset(data.aws_availability_zones.azs.names)
    depends_on              = [aws_vpc.rosa-vpc]
    vpc_id                  = aws_vpc.rosa-vpc.id
    cidr_block              = "10.1.2${index(data.aws_availability_zones.azs.names, each.value) + 1}.0/24"
    map_public_ip_on_launch = "false"
    availability_zone       = each.value
    tags = {
        Owner = var.cluster_owner_tag
        Name  = "${var.env_name}-subnet-pub-${each.key}"
    }
}

resource "aws_vpc" "egress-vpc" {
    cidr_block           = "${var.egress_vpc_cidr}"
    enable_dns_support   = "true"
    enable_dns_hostnames = "true"
    instance_tenancy     = "default"
    tags = {
        Owner = var.cluster_owner_tag
        Name  = "${var.egress_env_name}-vpc"
    }
}

resource "aws_subnet" "egress-subnet-priv" {
    for_each                = toset(data.aws_availability_zones.azs.names)
    depends_on              = [aws_vpc.egress-vpc]
    vpc_id                  = aws_vpc.egress-vpc.id
    cidr_block              = "10.0.1${index(data.aws_availability_zones.azs.names, each.value) + 1}.0/24"
    map_public_ip_on_launch = "false"
    availability_zone       = each.value
    tags = {
        Owner = var.cluster_owner_tag
        Name  = "${var.egress_env_name}-subnet-priv-${each.key}"
    }
}

resource "aws_subnet" "egress-subnet-pub" {
    for_each                = toset(data.aws_availability_zones.azs.names)
    depends_on              = [aws_vpc.egress-vpc]
    vpc_id                  = aws_vpc.egress-vpc.id
    cidr_block              = "10.0.2${index(data.aws_availability_zones.azs.names, each.value) + 1}.0/24"
    map_public_ip_on_launch = "false"
    availability_zone       = each.value
    tags = {
        Owner = var.cluster_owner_tag
        Name  = "${var.egress_env_name}-subnet-pub-${each.key}"
    }
}

resource "aws_internet_gateway" "egress-igw" {
    vpc_id = aws_vpc.egress-vpc.id
    tags = {
        Owner = var.cluster_owner_tag
        Name  = "${var.egress_env_name}-igw"
    }
}

resource "aws_route_table_association" "egress-public-rta" {
    for_each  = toset(data.aws_availability_zones.azs.names)
    subnet_id = aws_subnet.egress-subnet-pub[each.value].id
    route_table_id = aws_route_table.egress-public-rt[each.value].id
}

resource "aws_route_table_association" "egress-private-rta" {
    for_each  = toset(data.aws_availability_zones.azs.names)
    subnet_id = aws_subnet.egress-subnet-priv[each.value].id
    route_table_id = aws_route_table.egress-private-rt[each.value].id
}

resource "aws_route_table_association" "rosa-public-rt" {
    for_each       = toset(data.aws_availability_zones.azs.names)
    subnet_id      = aws_subnet.rosa-subnet-pub[each.value].id
    route_table_id = aws_route_table.rosa-public-rt[each.value].id
}

resource "aws_route_table_association" "rosa-private-rta" {
    for_each       = toset(data.aws_availability_zones.azs.names)
    subnet_id      = aws_subnet.rosa-subnet-priv[each.value].id
    route_table_id = aws_route_table.rosa-private-rt[each.value].id
}

resource "aws_eip" "egress-eip" {
    for_each     = toset(data.aws_availability_zones.azs.names)
    vpc          = true
    depends_on   = [aws_internet_gateway.egress-igw]
    tags = {
        Owner = "${var.cluster_owner_tag}"
        Name  = "${var.egress_env_name}-eip-${each.value}"
    }
}

resource "aws_nat_gateway" "egress-natgw" {
    for_each      = toset(data.aws_availability_zones.azs.names)
    allocation_id = aws_eip.egress-eip[each.value].id
    subnet_id     = aws_subnet.egress-subnet-pub[each.value].id
    //depends_on    = [aws_eip.rosa-eip[each.value]]

    tags = {
        Owner = "${var.cluster_owner_tag}"
        Name  = "${var.egress_env_name}-natgw"
    }
}

resource "aws_ec2_transit_gateway" "transit_gateway" {
    description = "Transit Gateway"
    tags = {
      Name = "transit_gateway"
    }
  }

resource "aws_route_table" "egress-public-rt" {
    for_each     = toset(data.aws_availability_zones.azs.names)
    vpc_id       = aws_vpc.egress-vpc.id
    depends_on   = [aws_internet_gateway.egress-igw]
    route {
        //route to rosa cluster VPC
        cidr_block = "10.1.0.0/16"
        transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    }

    // IGW must be the DF GW - OTHERWISE traffic ingressing to egress public VPN could not reach the bastion host
    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.egress-igw.id
    }
    tags = {
        Owner = var.cluster_owner_tag
        Name = "${var.egress_env_name}-public-rt-${each.value}"
    }
}

resource "aws_route_table" "egress-private-rt" {
    for_each     = toset(data.aws_availability_zones.azs.names)
    vpc_id       = aws_vpc.egress-vpc.id
    //depends_on    = [aws_eip.rosa-eip[each.value]]

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.egress-natgw[each.value].id
    }

    //Route for the ROSA cluster - private subnets
    route {
        //route to rosa cluster
        cidr_block = "10.1.0.0/16"
        transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    }

    tags = {
        Owner = var.cluster_owner_tag
        Name = "${var.egress_env_name}-private-rt-${each.value}"
    }
}

resource "aws_route_table" "rosa-public-rt" {
    for_each  = toset(data.aws_availability_zones.azs.names)
    vpc_id    = aws_vpc.rosa-vpc.id

    route {
        //associated subnet DF GW - required to reach the bastion public (that is in the egress VPC)
        cidr_block = "0.0.0.0/0"
        transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    }
    tags = {
        Owner = var.cluster_owner_tag
        Name = "${var.env_name}-public-rt-${each.value}"
    }
}

resource "aws_route_table" "rosa-private-rt" {
    for_each  = toset(data.aws_availability_zones.azs.names)
    vpc_id    = aws_vpc.rosa-vpc.id

    route {
        //associated subnet DF GW
        cidr_block = "0.0.0.0/0"
        transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    }
    tags = {
        Owner = var.cluster_owner_tag
        Name = "${var.env_name}-private-rt-${each.value}"
    }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "rosa_vpc_attachment" {
    //for_each      = toset(data.aws_availability_zones.azs.names)
    //subnet_ids     = [aws_subnet.rosa-subnet-pub[each.value].id]
    subnet_ids = [for az in aws_subnet.rosa-subnet-priv: az.id]
    transit_gateway_id       = aws_ec2_transit_gateway.transit_gateway.id
    vpc_id                   = aws_vpc.rosa-vpc.id
    
    tags = {
      Name = "transit-gw-rosa-attachment"
    }
  }
  
resource "aws_ec2_transit_gateway_vpc_attachment" "egress_vpc_attachment" {
    //for_each      = toset(data.aws_availability_zones.azs.names)
    //subnet_ids     = [aws_subnet.egress-subnet-pub[each.value].id]
    subnet_ids = [for az in aws_subnet.egress-subnet-priv: az.id]
    transit_gateway_id       = aws_ec2_transit_gateway.transit_gateway.id
    vpc_id                   = aws_vpc.egress-vpc.id
  
    tags = {
      Name = "transit-gw-egress-attachment"
    }
  }

resource "aws_ec2_transit_gateway_route" "tgw_rt" {
    //Configure TGW with a DF RT of the egress VPC (to egress to internet) 
    destination_cidr_block         = "0.0.0.0/0"
    transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress_vpc_attachment.id
    transit_gateway_route_table_id = aws_ec2_transit_gateway.transit_gateway.association_default_route_table_id
}

//==== Bastion Host "From Internet" Creation ====

//module "bastion_from_internet" {
//   source            = "../../modules/bastion"
//   depends_on        = [aws_vpc.egress-vpc]
//   aws_region        = var.aws_region
//   ami               = var.generic_ami[var.aws_region]
//   env_name          = var.egress-env_name
//   cluster_name      = var.cluster_name
//   cluster_owner_tag = var.cluster_owner_tag
//   vpc_ID            = aws_vpc.egress-vpc.id
//   igw_ID            = aws_internet_gateway.egress-igw.id
//   azs               = data.aws_availability_zones.azs.names[0]
//   pubkey            = var.pubkey
//}


/*
resource "aws_key_pair" "bastion-keypair" {
    key_name   = "${var.egress_env_name}-keypair"
    public_key = var.pubkey
    tags       = {
        Owner = var.cluster_owner_tag
        Name  = "${var.egress_env_name}-keypair"
    }
}
*/

resource "aws_security_group" "egress-vpc-bastion-sg" {
    name        = "${var.egress_env_name}-sg"
    description = "Allow SSH inbound traffic and allow all outbound"
    vpc_id                  = aws_vpc.egress-vpc.id
    tags        = {
        Owner = var.cluster_owner_tag
        Name  = "${var.egress_env_name}-sg"
    }
    ingress {
        description      = "SSH"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    }
}


//(authorized_key = pub)                       
//(manualmiente generate keys (pub+priv))                   (Terraform keys (pub+priv) )                  (authorized_key = pub)
//          Cliente (ssh -i priv ec2-user@bastion1)    ->  Bastion1 (ssh -i priv ec2-user@bastion2)   ->         Bastion2 -> OCP



//To get the private key - after terraform runs
//terraform output -raw private_key
output "private_key" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

// Creation ssh key pairs - to be used in Bastion Internet VM 
resource "tls_private_key" "ssh" {
    algorithm = "RSA"
    rsa_bits  = "4096"
}

resource "aws_key_pair" "generated_key" {
    key_name   = "mykey"
    public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_instance" "egress-vpc-bastion" {
    ami                           = var.generic_ami[var.aws_region]
    associate_public_ip_address   = true
    instance_type                 = "t3.micro"
    private_ip                    = "10.0.21.100"    // egress vpc subnet_public
    key_name                      = aws_key_pair.generated_key.key_name
    subnet_id                     = local.subnets_egress_pub[0]
    vpc_security_group_ids        = [aws_security_group.egress-vpc-bastion-sg.id]
    user_data                     = templatefile("../../modules/bastion/templates/user_data.sh.tftpl", {username = "ec2-user"})
    tags                          = {
        Owner = var.cluster_owner_tag
        Name  = "${var.egress_env_name}-bastion"
    }
    credit_specification {
        cpu_credits = "unlimited"
    }
}

resource "aws_security_group" "rosa-vpc-bastion-sg" {
    name        = "${var.env_name}-sg"
    description = "Allow SSH inbound traffic"
    vpc_id                  = aws_vpc.rosa-vpc.id
    tags        = {
        Owner = var.cluster_owner_tag
        Name  = "${var.env_name}-bastion-sg"
    }
    ingress {
        description      = "SSH"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    }
}

// Creation Bastion ROSA VM
resource "aws_instance" "rosa-vpc-bastion" {
    ami                           = var.generic_ami[var.aws_region]
    associate_public_ip_address   = false
    instance_type                 = "t3.micro"
//    private_ip                    = "10.1.23.100"    // rosa vpc subnet_public
    //https://www.phillipsj.net/posts/generating-ssh-keys-with-terraform/
    key_name                      = aws_key_pair.generated_key.key_name    
    subnet_id                     = local.subnets_rosa_pub[0]     //rosa_vpc subnet_public - bastion only in one AZ - grabs only one AZ subnet
    vpc_security_group_ids        = [aws_security_group.rosa-vpc-bastion-sg.id]
    user_data                     = templatefile("../../modules/bastion/templates/user_data.sh.tftpl", {username = "ec2-user"})
    tags                          = {
        Owner = var.cluster_owner_tag
        Name  = "${var.env_name}-bastion"
    }
    credit_specification {
       cpu_credits = "unlimited"
    }
}
