# Get home IP address for access to NGINX application
variable "home_ip_address" {
    type        = string
    description = "enter your home IP"
}

# Access the NGINX application using the Load Balancer DNS record
output "nginx_lb_url" {
    value = aws_lb.nginx.dns_name
}

# Access the NGINX application using the Instance public IP
output "nginx_instance_public_ip" {
    value = aws_instance.nginx.public_ip
}