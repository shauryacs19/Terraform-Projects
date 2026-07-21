resource "aws_vpc" "primary_vpc" {
  cidr_block = var.primary_vpc_cidr
  provider = aws.primary
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "Primary-VPC-${var.primary}"
  }
}

resource "aws_vpc" "secondary_vpc" {
  cidr_block = var.secondary_vpc_cidr
  provider = aws.secondary
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "Secondary-VPC-${var.secondary}"
  }
}

resource "aws_subnet" "primary_subnet" {
  provider = aws.primary
  vpc_id = aws_vpc.primary_vpc.id
  cidr_block = cidrsubnet(var.primary_vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.primary.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Primary-Subnet-${var.primary}"
    Environment = var.environment
  }
}

resource "aws_subnet" "secondary_subnet" {
  provider = aws.secondary
  vpc_id = aws_vpc.secondary_vpc.id
  cidr_block = cidrsubnet(var.secondary_vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.secondary.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Secondary-Subnet-${var.secondary}"
    Environment = var.environment
  }
  
}

resource "aws_internet_gateway" "primary_igw" {
  provider = aws.primary
  vpc_id = aws_vpc.primary_vpc.id

  tags = {
    Name = "Primary-IGW-${var.primary}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "secondary_igw" {
  provider = aws.secondary
  vpc_id = aws_vpc.secondary_vpc.id

  tags = {
    Name = "Secondary-IGW-${var.secondary}"
    Environment = var.environment
  }
}

resource "aws_route_table" "primary_rt" {
  provider = aws.primary
  vpc_id = aws_vpc.primary_vpc.id

  tags = {
    Name = "Primary-Route-Table-${var.primary}"
    Environment = var.environment
  }
}

resource "aws_route_table" "secondary_rt" {
  provider = aws.secondary
  vpc_id = aws_vpc.secondary_vpc.id

  tags = {
    Name = "Secondary-Route-Table-${var.secondary}"
    Environment = var.environment
  }
}

resource "aws_route" "primary_internet_route" {
  provider = aws.primary
  route_table_id = aws_route_table.primary_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.primary_igw.id
}

resource "aws_route" "secondary_internet_route" {
  provider = aws.secondary
  route_table_id = aws_route_table.secondary_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.secondary_igw.id
}

resource "aws_route_table_association" "primary_rta" {
  provider = aws.primary
  subnet_id = aws_subnet.primary_subnet.id
  route_table_id = aws_route_table.primary_rt.id
}

resource "aws_route_table_association" "secondary_rta" {
  provider = aws.secondary
  subnet_id = aws_subnet.secondary_subnet.id
  route_table_id = aws_route_table.secondary_rt.id
}

resource "aws_vpc_peering_connection" "primary_to_secondary" {
  provider = aws.primary
  vpc_id = aws_vpc.primary_vpc.id
  peer_vpc_id = aws_vpc.secondary_vpc.id
  peer_region = var.secondary
  auto_accept = false

  tags = {
    Name = "VPC-Peering-${var.primary}-${var.secondary}"
    Environment = var.environment
    Side = "Accepter"
  }
}

resource "aws_vpc_peering_connection_accepter" "secondary_accepter" {
  provider = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  auto_accept = true

  tags = {
    Name = "VPC-Peering-${var.secondary}-${var.primary}"
    Environment = var.environment
    Side = "Requester"
  }
}

resource "aws_route" "primary_to_secondary_route" {
  provider = aws.primary
  route_table_id = aws_route_table.primary_rt.id
  destination_cidr_block = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}

resource "aws_route" "secondary_to_primary_route" {
  provider = aws.secondary
  route_table_id = aws_route_table.secondary_rt.id
  destination_cidr_block = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}

resource "aws_security_group" "primary_sg" {
  provider = aws.primary
  name = "Primary-SG-${var.primary}"
  description = "Security group for primary VPC"
  vpc_id = aws_vpc.primary_vpc.id

  ingress {
    description = "Allow SSH from anywhere"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ICMP from anywhere"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [var.secondary_vpc_cidr]
  }

  ingress {
    description = "All traffic from secondary VPC"
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = [var.secondary_vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Primary-SG-${var.primary}"
    Environment = var.environment
  }
}

resource "aws_security_group" "secondary_sg" {
  provider = aws.secondary
  name = "Secondary-SG-${var.secondary}"
  description = "Security group for secondary VPC"
  vpc_id = aws_vpc.secondary_vpc.id

  ingress {
    description = "Allow SSH from anywhere"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ICMP from anywhere"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [var.primary_vpc_cidr]
  }

  ingress {
    description = "All traffic from primary VPC"
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = [var.primary_vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Secondary-SG-${var.secondary}"
    Environment = var.environment
  }
}

resource "aws_instance" "primary_instance" {
  provider = aws.primary
  ami = data.aws_ami.primary_ami.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.primary_subnet.id
  vpc_security_group_ids = [aws_security_group.primary_sg.id]
  key_name = var.primary_key_name
  user_data = local.primary_user_data
  private_ip = cidrhost(cidrsubnet(var.primary_vpc_cidr, 8, 1), 10)

  tags = {
    Name = "Primary-Instance-${var.primary}"
    Environment = var.environment
  }
}

resource "aws_instance" "secondary_instance" {
  provider = aws.secondary
  ami = data.aws_ami.secondary_ami.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.secondary_subnet.id
  vpc_security_group_ids = [aws_security_group.secondary_sg.id]
  key_name = var.secondary_key_name
  user_data = local.secondary_user_data
  private_ip = cidrhost(cidrsubnet(var.secondary_vpc_cidr, 8, 1), 10)

  tags = {
    Name = "Secondary-Instance-${var.secondary}"
    Environment = var.environment
  }
}