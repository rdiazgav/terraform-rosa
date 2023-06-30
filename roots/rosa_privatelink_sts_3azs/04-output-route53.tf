output "rosa_private_zone_domain" {
    value     = base64decode(base64encode(file("${path.module}/private-hosted-zone-name.txt")))

}