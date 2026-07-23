resource "aws_vpc" "primary_vpc" {
  provider             = aws.primary
  cidr_block           = var.primary_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Primary-VPC-${var.primary}"
  }
}

resource "aws_vpc" "secondary_vpc" {
  provider             = aws.secondary
  cidr_block           = var.secondary_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Secondary-VPC-${var.secondary}"
  }
}

resource "aws_subnet" "primary_subnet" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.primary_vpc.id
  cidr_block              = cidrsubnet(var.primary_vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.primary.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "Primary-Subnet-${var.primary}"
    Environment = var.environment
  }
}

resource "aws_subnet" "secondary_subnet" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary_vpc.id
  cidr_block              = cidrsubnet(var.secondary_vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.secondary.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "Secondary-Subnet-${var.secondary}"
    Environment = var.environment
  }
}

resource "aws_route_table" "primary_route_table" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary_vpc.id

  tags = {
    Name        = "Primary-Route-Table-${var.primary}"
    Environment = var.environment
  }
}

resource "aws_route_table" "secondary_route_table" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_vpc.id

  tags = {
    Name        = "Secondary-Route-Table-${var.secondary}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "primary_igw" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary_vpc.id

  tags = {
    Name        = "Primary-IGW-${var.primary}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "secondary_igw" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_vpc.id

  tags = {
    Name        = "Secondary-IGW-${var.secondary}"
    Environment = var.environment
  }
}

# --- VPC route tables: default internet route, peer CIDR via local TGW, and subnet association ---
resource "aws_route" "primary_internet_route" {
  provider               = aws.primary
  route_table_id         = aws_route_table.primary_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.primary_igw.id
}

resource "aws_route" "secondary_internet_route" {
  provider               = aws.secondary
  route_table_id         = aws_route_table.secondary_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.secondary_igw.id
}

resource "aws_route" "primary_to_secondary_route" {
  provider               = aws.primary
  route_table_id         = aws_route_table.primary_route_table.id
  destination_cidr_block = var.secondary_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.primary_tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.primary_vpc_attachment]
}

resource "aws_route" "secondary_to_primary_route" {
  provider               = aws.secondary
  route_table_id         = aws_route_table.secondary_route_table.id
  destination_cidr_block = var.primary_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.secondary_tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.secondary_vpc_attachment]
}

resource "aws_route_table_association" "primary_rta" {
  provider       = aws.primary
  subnet_id      = aws_subnet.primary_subnet.id
  route_table_id = aws_route_table.primary_route_table.id
}

resource "aws_route_table_association" "secondary_rta" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_subnet.id
  route_table_id = aws_route_table.secondary_route_table.id
}

resource "aws_security_group" "primary_sg" {
  provider    = aws.primary
  name        = "Primary-SG-${var.primary}"
  description = "Security group for primary VPC"
  vpc_id      = aws_vpc.primary_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP from peer VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.secondary_vpc_cidr]
  }

  ingress {
    description = "All TCP from peer VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.secondary_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Primary-SG-${var.primary}"
  }
}

resource "aws_security_group" "secondary_sg" {
  provider    = aws.secondary
  name        = "Secondary-SG-${var.secondary}"
  description = "Security group for secondary VPC"
  vpc_id      = aws_vpc.secondary_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP from peer VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.primary_vpc_cidr]
  }

  ingress {
    description = "All TCP from peer VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.primary_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Secondary-SG-${var.secondary}"
  }
}

# ---------------- Transit Gateways (one per region) ----------------
resource "aws_ec2_transit_gateway" "primary_tgw" {
  provider                        = aws.primary
  description                     = "Transit Gateway - Mumbai"
  amazon_side_asn                 = 64512
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "tgw-${var.primary}"
  }
}

resource "aws_ec2_transit_gateway" "secondary_tgw" {
  provider                        = aws.secondary
  description                     = "Transit Gateway - Hyderabad"
  amazon_side_asn                 = 64513
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "tgw-${var.secondary}"
  }
}

# ---------------- Attach each VPC to its local TGW ----------------
resource "aws_ec2_transit_gateway_vpc_attachment" "primary_vpc_attachment" {
  provider           = aws.primary
  subnet_ids         = [aws_subnet.primary_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.primary_tgw.id
  vpc_id             = aws_vpc.primary_vpc.id

  tags = {
    Name = "TGW-Attach-${var.primary}"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "secondary_vpc_attachment" {
  provider           = aws.secondary
  subnet_ids         = [aws_subnet.secondary_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.secondary_tgw.id
  vpc_id             = aws_vpc.secondary_vpc.id

  tags = {
    Name = "TGW-Attach-${var.secondary}"
  }
}

# ---------------- Cross-region TGW peering ----------------
resource "aws_ec2_transit_gateway_peering_attachment" "tgw_peer" {
  provider                = aws.primary
  transit_gateway_id      = aws_ec2_transit_gateway.primary_tgw.id
  peer_transit_gateway_id = aws_ec2_transit_gateway.secondary_tgw.id
  peer_account_id         = aws_ec2_transit_gateway.secondary_tgw.owner_id
  peer_region             = var.secondary

  tags = {
    Name = "TGW-Peering-${var.primary}-${var.secondary}"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "secondary_accepter" {
  provider                      = aws.secondary
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.tgw_peer.id

  tags = {
    Name = "TGW-Peering-Accepter-${var.secondary}"
  }
}

# ---------------- Custom TGW route tables ----------------
resource "aws_ec2_transit_gateway_route_table" "primary_tgw_route_table" {
  provider           = aws.primary
  transit_gateway_id = aws_ec2_transit_gateway.primary_tgw.id

  tags = {
    Name = "TGW-RT-${var.primary}"
  }
}

resource "aws_ec2_transit_gateway_route_table" "secondary_tgw_route_table" {
  provider           = aws.secondary
  transit_gateway_id = aws_ec2_transit_gateway.secondary_tgw.id

  tags = {
    Name = "TGW-RT-${var.secondary}"
  }
}

# ---------------- Route-table associations (which RT an attachment uses) ----------------
resource "aws_ec2_transit_gateway_route_table_association" "primary_vpc_assoc" {
  provider                       = aws.primary
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.primary_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary_tgw_route_table.id
}

resource "aws_ec2_transit_gateway_route_table_association" "secondary_vpc_assoc" {
  provider                       = aws.secondary
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.secondary_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary_tgw_route_table.id
}

# The peering attachment must also be associated so traffic ARRIVING from the
# peer region is routed to the local VPC.
resource "aws_ec2_transit_gateway_route_table_association" "primary_peer_assoc" {
  provider                       = aws.primary
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peer.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary_tgw_route_table.id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.secondary_accepter]
}

resource "aws_ec2_transit_gateway_route_table_association" "secondary_peer_assoc" {
  provider                       = aws.secondary
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peer.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary_tgw_route_table.id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.secondary_accepter]
}

# ---------------- Propagate each LOCAL VPC CIDR into its TGW route table ----------------
resource "aws_ec2_transit_gateway_route_table_propagation" "primary_vpc_prop" {
  provider                       = aws.primary
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.primary_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary_tgw_route_table.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "secondary_vpc_prop" {
  provider                       = aws.secondary
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.secondary_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary_tgw_route_table.id
}

# ---------------- Static routes for the REMOTE CIDR via the peering attachment ----------------
resource "aws_ec2_transit_gateway_route" "primary_to_secondary" {
  provider                       = aws.primary
  destination_cidr_block         = var.secondary_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peer.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary_tgw_route_table.id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.secondary_accepter]
}

resource "aws_ec2_transit_gateway_route" "secondary_to_primary" {
  provider                       = aws.secondary
  destination_cidr_block         = var.primary_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peer.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary_tgw_route_table.id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.secondary_accepter]
}

# ---------------- Key pairs (one per region, least privilege) ----------------
resource "aws_key_pair" "primary_key" {
  provider   = aws.primary
  key_name   = var.primary_key_name
  public_key = file(var.primary_public_key_path)
}

resource "aws_key_pair" "secondary_key" {
  provider   = aws.secondary
  key_name   = var.secondary_key_name
  public_key = file(var.secondary_public_key_path)
}

# ---------------- EC2 instances (to validate connectivity across the TGW) ----------------
resource "aws_instance" "primary_instance" {
  provider               = aws.primary
  ami                    = data.aws_ami.primary_ami.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.primary_subnet.id
  vpc_security_group_ids = [aws_security_group.primary_sg.id]
  key_name               = aws_key_pair.primary_key.key_name
  user_data              = local.primary_user_data
  private_ip             = cidrhost(cidrsubnet(var.primary_vpc_cidr, 8, 1), 10)

  tags = {
    Name        = "Primary-Instance-${var.primary}"
    Environment = var.environment
  }
}

resource "aws_instance" "secondary_instance" {
  provider               = aws.secondary
  ami                    = data.aws_ami.secondary_ami.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.secondary_subnet.id
  vpc_security_group_ids = [aws_security_group.secondary_sg.id]
  key_name               = aws_key_pair.secondary_key.key_name
  user_data              = local.secondary_user_data
  private_ip             = cidrhost(cidrsubnet(var.secondary_vpc_cidr, 8, 1), 10)

  tags = {
    Name        = "Secondary-Instance-${var.secondary}"
    Environment = var.environment
  }
}
