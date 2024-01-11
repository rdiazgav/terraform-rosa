data "aws_caller_identity" "current" {}

data "aws_availability_zones" "azs" {
    state = "available"
    filter {
    name   = "zone-name"
    values = data.aws_availability_zones.azs.names[0]
  }
    filter {
        name   = "region-name"
        values = [var.aws_region]
    }
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
    //vpc          = true
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
    subnet_ids = [for az in aws_subnet.rosa-subnet-priv: az.id]
    transit_gateway_id       = aws_ec2_transit_gateway.transit_gateway.id
    vpc_id                   = aws_vpc.rosa-vpc.id
    
    tags = {
      Name = "transit-gw-rosa-attachment"
    }
}
  
resource "aws_ec2_transit_gateway_vpc_attachment" "egress_vpc_attachment" {    
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
