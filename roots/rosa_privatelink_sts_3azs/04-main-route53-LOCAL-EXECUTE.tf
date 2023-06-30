resource "null_resource" "get_cluster_dns_zone" {
  triggers  =  { 
    always_run   = "${timestamp()}" 
    cluster_name = var.cluster_name
  }
  provisioner "local-exec" {
    command = "aws route53 list-hosted-zones | jq -r '.HostedZones[].Name' | grep -i '^${self.triggers.cluster_name}.' | tr -d '\n' > ${path.module}/private-hosted-zone-name.txt"
  }
  depends_on = [null_resource.rosa_cli_installer]
}

data "local_file" "private-hosted-zone-name" {
  filename = "${path.module}/private-hosted-zone-name.txt"
  depends_on = [null_resource.get_cluster_dns_zone]
}

data "aws_route53_zone" "private_rosa_dns_zone" {  
  private_zone = true  
  name = "${data.local_file.private-hosted-zone-name.content}"

  depends_on = [data.local_file.private-hosted-zone-name]
}

resource "aws_route53_zone_association" "egress-rosa-resolver-vpc-assotiation" {
  zone_id = data.aws_route53_zone.private_rosa_dns_zone.id
  vpc_id  = aws_vpc.egress-vpc.id
}

resource "aws_security_group" "rosa-resolution-sg" {
  name        = "allow-dns"
  description = "Allow DNS inbound traffic"
  vpc_id      = aws_vpc.egress-vpc.id

  ingress {
    description      = "DNS (TCP)"
    from_port        = 53
    to_port          = 53
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "DNS (UDP)"
    from_port        = 53
    to_port          = 53
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_route53_resolver_endpoint" "rosa-resolver-inbound-endpoint" {
  name      = "rosa-resolver-inbound-endpoint"
  direction = "INBOUND"

  security_group_ids = [aws_security_group.rosa-resolution-sg.id]

  dynamic "ip_address" {
    for_each = data.aws_availability_zones.azs.names
    content {
      subnet_id = aws_subnet.egress-subnet-pub[ip_address.value].id  
    }
  }
}
