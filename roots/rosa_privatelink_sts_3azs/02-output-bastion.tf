output "bastion_ip" {
    value = "${aws_instance.egress-vpc-bastion.public_ip}"
}

output "bastion_private_key" {
    value     = tls_private_key.ssh.private_key_pem
    sensitive = true
}

output "script-connect-ssm" {
    value = <<EOF
aws ssm start-session --target="${aws_instance.egress-vpc-bastion.id}"
EOF
    description = "Script to connect via AWS CLI to instance"
}