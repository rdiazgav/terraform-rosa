locals {
   subnets = join(",", [for subnet in aws_subnet.rosa-subnet-priv: subnet.id])
}