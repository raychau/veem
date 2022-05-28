# Veem VPC
resource "aws_vpc" "veem" {
    cidr_block = "10.0.0.0/16"

    tags = {
        "Name" = "veem"
    }
}

### Two Public Subnets in two different Availability Zones
### are required for Application Load Balancers to be initialized
# Create Public Subnet A
resource "aws_subnet" "public_a" {
    vpc_id     = aws_vpc.veem.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"

    tags = {
        "Name" = "veem public a"
    }
}
# Create Public Subnet B
resource "aws_subnet" "public_b" {
    vpc_id     = aws_vpc.veem.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"

    tags = {
        "Name" = "veem public b"
    }
}

# Create Veem VPC internet gateway
resource "aws_internet_gateway" "veem" {
    vpc_id = aws_vpc.veem.id
}

# Set routes for default route table for Veem VPC
resource "aws_default_route_table" "veem" {
    default_route_table_id = aws_vpc.veem.default_route_table_id

    # Set the Default Route to the Veem VPC internet gateway
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.veem.id
    }

    tags = {
        "Name" = "veem"
    }
}

# Associate Public Subnet A to Veem route table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_default_route_table.veem.id
}

# Associate Public Subnet B to Veem route table
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_default_route_table.veem.id
}