resource "aws_vpc" "main" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "demo-test"
  }
}

resource "aws_subnet" "public" {

  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "demo-igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "demo-igw"
  }
}


resource "aws_route_table" "routetable" {

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public" {

  subnet_id = aws_subnet.public.id

  route_table_id = aws_route_table.routetable.id
}


resource "aws_security_group" "web-sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH inbound traffic"

  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "web-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}


resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

# Allow SSH from your own public IP
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_my_ip" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "103.75.43.224/32"   # replace with your actual IP
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners     = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
}

data "aws_ssm_parameter" "ec2_key_pair" {
  name = "/demo/keypair/ec2"
}

data "aws_key_pair" "ec2_key" {
  key_name = data.aws_ssm_parameter.ec2_key_pair.value
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = data.aws_key_pair.ec2_key.key_name
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.web-sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "web-instance"
  }
}

resource "aws_s3_bucket" "app-bucket" {
  bucket = "demo-test-bucket-20260632"

  tags = {
    Name = "app-bucket"
    Environment = "Demo"
  }
}

resource "aws_iam_role" "ec2_role" {

  name = "demo-ec2-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "demo-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {

  role = aws_iam_role.ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {

  name = "demo-profile"

  role = aws_iam_role.ec2_role.name
}
