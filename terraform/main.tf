# Create Jenkins EC2 instance

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "jenkins_vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name  = "jenkins-vpc"
    usage = "Jenkins"
  }
}

resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-key"
  public_key = var.public_key
}

resource "aws_subnet" "jenkins_subnet" {
  vpc_id            = aws_vpc.jenkins_vpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name  = "jenkins-subnet"
    usage = "Jenkins"
  }
}

resource "aws_internet_gateway" "jenkins_igw" {
  vpc_id = aws_vpc.jenkins_vpc.id

  tags = {
    Name  = "jenkins-igw"
    usage = "Jenkins"
  }
}

resource "aws_route_table" "jenkins_rt" {
  vpc_id = aws_vpc.jenkins_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_igw.id
  }

  tags = {
    Name  = "jenkins-rt"
    usage = "Jenkins"
  }
}

resource "aws_route_table_association" "jenkins_rt_assoc" {
  subnet_id      = aws_subnet.jenkins_subnet.id
  route_table_id = aws_route_table.jenkins_rt.id
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins UI"
  vpc_id      = aws_vpc.jenkins_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ALL
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ALL
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "jenkins-sg"
    usage = "Jenkins"
  }
}

resource "aws_network_interface" "jenkins_network_interface" {
  subnet_id       = aws_subnet.jenkins_subnet.id
  private_ips     = ["172.16.10.100"]
  security_groups = [aws_security_group.jenkins_sg.id]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_eip" "jenkins_eip" {
  domain            = "vpc"
  network_interface = aws_network_interface.jenkins_network_interface.id

  tags = {
    Name  = "jenkins-eip"
    usage = "Jenkins"
  }
}

resource "aws_instance" "jenkinshost" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = aws_key_pair.jenkins_key.key_name

  primary_network_interface {
    network_interface_id = aws_network_interface.jenkins_network_interface.id
  }

  tags = {
    Name  = "jenkins-master"
    usage = "Jenkins-Master"
  }

}

# output Jenkins-master public IP
output "jenkins_public_ip" {
  value = aws_eip.jenkins_eip.public_ip
}