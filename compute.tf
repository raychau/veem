##############################
#
# SECURITY GROUP
#
##############################

## The load balancer can be accessed only by the provided Home IP address
# Create Nginx Load Balancer security group
resource "aws_security_group" "nginx_lb" {
    name        = "nginx-lb-sg"
    description = "network defaults for nginx application"
    vpc_id      = aws_vpc.veem.id

    # Allow ingress of port 80 from all Home IP addresses
    ingress {
        description      = "HTTP"
        from_port        = 80
        to_port          = 80
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    # Allow ingress of port 443 from all Home IP addresses
    ingress {
        description      = "HTTPS"
        from_port        = 443
        to_port          = 443
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    # Default egress all
    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    tags = {
        Name = "nginx lb - allow_http/s"
    }
}

## The instance itself can only be accessed by the Load Balancer
# Create Nginx Instance security group
resource "aws_security_group" "nginx_instance" {
    name        = "nginx-instance-sg"
    description = "network defaults for nginx application"
    vpc_id      = aws_vpc.veem.id

    # Allow ingress to port 80 from Load Balancer
    ingress {
        description      = "HTTP"
        from_port        = 80
        to_port          = 80
        protocol         = "tcp"
        security_groups  = [aws_security_group.nginx_lb.id]
    }

    # Allow ingress to port 443 from Load Balancer
    ingress {
        description      = "HTTPS"
        from_port        = 443
        to_port          = 443
        protocol         = "tcp"
        security_groups  = [aws_security_group.nginx_lb.id]
    }

    # Allow ingress to port 22 from provided Home IP address
    ingress {
        description      = "SSH"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = ["${var.home_ip_address}/32"]
    }

    # Default egress all
    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    tags = {
        Name = "nginx instance - allow_http/s"
    }
}

##############################
#
# Instance
#
##############################

# Reference Bitnami open source nginx AMI
data "aws_ami" "nginx" {
    filter {
        name   = "image-id"
        values = ["ami-065fd120b53e81651"]
    }

    owners = ["979382823631"]
}

# Create Key pair
resource "aws_key_pair" "veem" {
  key_name   = "veem-challenge"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCSYofDSl6ztMtlP6rTS+oLi+8oVBVOJrbqgW+/PVANwP/u5QwmIed5mRymKOhHVsyHdGyJGPVC/cyyDzcFSdnPeLmkwlmA6HRN+rjtaleQ4WLxxJg+fiLY8UE9WYOd3HWTu+/BR9jojTKU7oHMwiM2wLWLiptRx9TJrIVeOe+6fI/S7yvsh2f8n2qUN5frAh+oDqEOVNhNmFp90k5oH/DZZ3z+6JjyNq40OC0CzkYcGkh2Vi9lLVcHqmSsUh3LXSbK331ZPT+tLSjkJFxMFSo12r2VHrH2tJoQlPU7wpRYdTWlOex3SCJIl5uYwZVb3SI6zcjS7lClV0sZkojvK78l"
}

# Create Instance using Bitnami nginx AMI
resource "aws_instance" "nginx" {
    ami                         = data.aws_ami.nginx.id
    instance_type               = "t3.micro"
    security_groups             = [aws_security_group.nginx_instance.id]

    # Associate ephemeral public IP address for SSH
    associate_public_ip_address = true

    # Arbitrarily associated with Public Subnet A
    subnet_id                   = aws_subnet.public_a.id

    # Key pair
    key_name = aws_key_pair.veem.key_name

    tags = {
        "Name" = "nginx"
    }
}

##############################
#
# LOAD BALANCING
#
##############################

# Create Nginx Target Group
resource "aws_lb_target_group" "nginx" {
    name     = "nginx-lb-tg"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.veem.id
}

# Attach Nginx Instance to Nginx Target Group
resource "aws_lb_target_group_attachment" "nginx" {
    target_group_arn = aws_lb_target_group.nginx.arn
    target_id        = aws_instance.nginx.id
}

# Create Nginx Load Balancer
resource "aws_lb" "nginx" {
    name               = "nginx-lb"
    security_groups    = [aws_security_group.nginx_lb.id]

    # Associate Veem Public Subnet A/B to the Load Balancer
    subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

# Set Nginx Load Balancer to listen to Port 80
resource "aws_lb_listener" "nginx_http" {
    load_balancer_arn = aws_lb.nginx.arn
    port              = "80"
    protocol          = "HTTP"

    # Forward traffic to Nginx Target Group
    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.nginx.arn
    }
}

# Set Nginx Load Balancer to listen to Port 443
resource "aws_lb_listener" "nginx_https" {
    load_balancer_arn = aws_lb.nginx.arn
    port              = "443"
    protocol          = "HTTP"

    ## Redirect traffic to Port 80 since HTTPS
    ## is not setup by default (needs SSL certs)
    default_action {
        type = "redirect"

        redirect {
        port        = "80"
        protocol    = "HTTP"
        status_code = "HTTP_301"
        }
    }
}