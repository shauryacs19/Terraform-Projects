data "aws_region" "peer" {
    provider = aws.secondary
}

data "aws_availability_zones" "primary" {
    provider = aws.primary
    state = "available"
}

data "aws_availability_zones" "secondary" {
    provider = aws.secondary
    state = "available"
}

data "aws_ami" "primary_ami" {
    provider = aws.primary
    most_recent = true
    owners = ["099720109477"]
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    filter {
        name = "architecture"
        values = ["x86_64"]
    }
}

data "aws_ami" "secondary_ami" {
    provider = aws.secondary
    most_recent = true
    owners = ["099720109477"]
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    filter {
        name = "architecture"
        values = ["x86_64"]
    }
}