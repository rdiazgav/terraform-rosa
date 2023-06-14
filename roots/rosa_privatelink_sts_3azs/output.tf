output "bastion_ip" {
    value = "${aws_instance.egress-vpc-bastion.public_ip}"
}

output "private_bastion_ip" {
    value= "${aws_instance.rosa-vpc-bastion.private_ip}"
}

output "bastion_private_key" {
    value     = tls_private_key.ssh.private_key_pem
    sensitive = true
}