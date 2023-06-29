#used in the Bastion egress/internet, to configure the bastion in the egress_vpc subnet_public
locals {
   subnets_egress_pub = [for subnet in aws_subnet.egress-subnet-pub: subnet.id]
}

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

// Creation ssh key pairs - to be used in Bastion Internet VM 
resource "tls_private_key" "ssh" {
    algorithm = "RSA"
    rsa_bits  = "4096"
}

resource "aws_key_pair" "generated_key" {
    key_name   = "bastion-key"
    public_key = tls_private_key.ssh.public_key_openssh
}

# Create an IAM role - Get the default policy by name
data "aws_iam_policy" "required-policy" {
  name = "AmazonSSMManagedEC2InstanceDefaultPolicy"
}

# Create the role
resource "aws_iam_role" "system-manager-ec2-role" {
  name = "AWSSystemManagerEC2Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach-system-manager" {
  role       = aws_iam_role.system-manager-ec2-role.name
  policy_arn = data.aws_iam_policy.required-policy.arn
}

# Create the instance profile for EC2
resource "aws_iam_instance_profile" "ec2-system-manager-instance-profile" {
  name = "${aws_iam_role.system-manager-ec2-role.name}"
  role = "${aws_iam_role.system-manager-ec2-role.name}"
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

    iam_instance_profile = aws_iam_instance_profile.ec2-system-manager-instance-profile.name    
}