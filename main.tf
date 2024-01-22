resource "aws_vpc" "vpc-1" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id                  = aws_vpc.vpc-1.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "gateway-1" {
  vpc_id = aws_vpc.vpc-1.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.vpc-1.id

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway-1.id

}

resource "aws_route_table_association" "public-rt-assoc" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_security_group" "sg-1" {
  name        = "dev-sg"
  description = "dev security group"
  vpc_id      = aws_vpc.vpc-1.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["96.248.41.102/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "ec2-auth" {
  key_name   = "ec2-key"
  public_key = file("~/.ssh/ec2-key.pub")
}

resource "aws_instance" "dev-node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.ec2-instance.id
  key_name               = aws_key_pair.ec2-auth.id
  vpc_security_group_ids = [aws_security_group.sg-1.id]
  subnet_id              = aws_subnet.subnet-1.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("windows-ssh-config.tpl", {
      hostname     = self.public_ip
      user         = "ubuntu"
      identityfile = "~/.ssh/ec2-key"
    })
    interpreter = ["Powershell", "-Command"] //Windows
    // interpreter = ["bash", "-c"] //Linux
  }
}