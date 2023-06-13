output "ip_bastion1" {
    value = "${aws_instance.egress-vpc-bastion.public_ip}"
}