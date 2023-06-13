output "ip_bastion" {
    value = "${aws_instance.egress-vpc-bastion.public_ip}"
}