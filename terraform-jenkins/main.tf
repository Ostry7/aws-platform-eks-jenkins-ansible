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
  cidr_block = var.vpc_cidr

  tags = {
    Name  = "${var.instance_name}-vpc"
    usage = var.usage_tag
  }
}

resource "aws_key_pair" "jenkins_key" {
  key_name   = "${var.instance_name}-key"
  public_key = var.public_key
}

resource "aws_subnet" "jenkins_subnet" {
  vpc_id            = aws_vpc.jenkins_vpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name  = "${var.instance_name}-subnet"
    usage = var.usage_tag
  }
}

resource "aws_internet_gateway" "jenkins_igw" {
  vpc_id = aws_vpc.jenkins_vpc.id

  tags = {
    Name  = "${var.instance_name}-igw"
    usage = var.usage_tag
  }
}

resource "aws_route_table" "jenkins_rt" {
  vpc_id = aws_vpc.jenkins_vpc.id

  route {
    cidr_block = var.security_group_cidr_blocks
    gateway_id = aws_internet_gateway.jenkins_igw.id
  }

  tags = {
    Name  = "${var.instance_name}-rt"
    usage = var.usage_tag
  }
}

resource "aws_route_table_association" "jenkins_rt_assoc" {
  subnet_id      = aws_subnet.jenkins_subnet.id
  route_table_id = aws_route_table.jenkins_rt.id
}

resource "aws_security_group" "jenkins_sg" {
  name        = "${var.instance_name}-sg"
  description = "Allow SSH and Jenkins UI"
  vpc_id      = aws_vpc.jenkins_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.security_group_cidr_blocks] # ALL
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.security_group_cidr_blocks] # ALL
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.security_group_cidr_blocks]
  }

  tags = {
    Name  = "${var.instance_name}-sg"
    usage = var.usage_tag
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
    Name  = "${var.instance_name}-eip"
    usage = var.usage_tag
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
    usage = "${var.usage_tag}-Master"
  }

}

# output Jenkins-master public IP
output "jenkins_master_public_ip" {
  value = aws_eip.jenkins_eip.public_ip
}

resource "aws_security_group" "jenkins_agent_sg" {
  name   = "jenkins-agent-sg"
  vpc_id = aws_vpc.jenkins_vpc.id

  ingress {
    description     = "SSH from Jenkins master only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-agent-sg" }
}

# Provision Jenkins agents
resource "aws_instance" "jenkins_agent_infra" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.jenkins_key.key_name
  subnet_id                   = aws_subnet.jenkins_subnet.id
  vpc_security_group_ids      = [aws_security_group.jenkins_agent_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jenkins_agent_infra_profile.name
  tags = {
    Name = "jenkins-agent_infra"
  }
}

# output Jenkins-agent infra public IP
output "jenkins_agent_infra_private_ip" {
  value = aws_instance.jenkins_agent_infra.private_ip
}

resource "aws_instance" "jenkins_agent_build" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.jenkins_key.key_name
  subnet_id                   = aws_subnet.jenkins_subnet.id
  vpc_security_group_ids      = [aws_security_group.jenkins_agent_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "jenkins-agent_build"
  }
}

# output Jenkins-agent build public IP
output "jenkins_agent_build_private_ip" {
  value = aws_instance.jenkins_agent_build.private_ip
}

# Create IAM role

resource "aws_iam_role" "jenkins_agent_infra_role" {
  name = "jenkins-agent-infra-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "jenkins_agent_infra_admin" {
  role       = aws_iam_role.jenkins_agent_infra_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # Admin for now
}

resource "aws_iam_instance_profile" "jenkins_agent_infra_profile" {
  name = "jenkins-agent-infra-profile"
  role = aws_iam_role.jenkins_agent_infra_role.name
}