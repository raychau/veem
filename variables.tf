# Get home IP address for access to NGINX application
variable "home_ip_address" {
    type        = string
    description = "enter your home IP"
}

# Access the NGINX application using the Load Balancer DNS record
output "nginx_url" {
    value = aws_lb.nginx.dns_name
}