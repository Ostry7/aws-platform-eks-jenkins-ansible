# create vpc for K8s cluster
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "eks-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "az1" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.az1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "az1_subnet"
  }
}

resource "aws_subnet" "az2" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.az2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "az2_subnet"
  }
}

resource "aws_subnet" "az3" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.az3_cidr
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true
  tags = {
    Name = "az3_subnet"
  }
}

resource "aws_eks_cluster" "K8s_cluster" {
  name = var.eks_cluster_name

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = [
      aws_subnet.az1.id,
      aws_subnet.az2.id,
      aws_subnet.az3.id,
    ]
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}

resource "aws_iam_role" "cluster" {
  name = "${var.eks_cluster_name}-cluster-role"
  assume_role_policy = jsonencode({

    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_access_entry" "roboticusr" {
  cluster_name  = aws_eks_cluster.K8s_cluster.name
  principal_arn = "arn:aws:iam::718980965007:user/roboticusr"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "roboticusr_admin" {
  cluster_name  = aws_eks_cluster.K8s_cluster.name
  principal_arn = "arn:aws:iam::718980965007:user/roboticusr"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Configure EC2 Self-Managed nodes
resource "aws_iam_role" "eks_node_role" {
  name = "${var.eks_cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.K8s_cluster.version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

resource "aws_launch_template" "eks_nodes" {
  name                   = "${var.eks_cluster_name}-node-template"
  instance_type          = var.instance_type
  image_id               = data.aws_ssm_parameter.eks_ami.value
  vpc_security_group_ids = [aws_eks_cluster.K8s_cluster.vpc_config[0].cluster_security_group_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.eks_node.name
  }

  user_data = base64encode(<<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${aws_eks_cluster.K8s_cluster.name}
    apiServerEndpoint: ${aws_eks_cluster.K8s_cluster.endpoint}
    certificateAuthority: ${aws_eks_cluster.K8s_cluster.certificate_authority[0].data}
    cidr: ${aws_eks_cluster.K8s_cluster.kubernetes_network_config[0].service_ipv4_cidr}

--BOUNDARY--
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.eks_cluster_name}-node"
    }
  }
}
resource "aws_autoscaling_group" "eks_nodes" {
  name              = "${var.eks_cluster_name}-nodes"
  desired_capacity  = var.node_desired_capacity
  max_size          = var.node_max_size
  min_size          = var.node_min_size
  target_group_arns = []
  vpc_zone_identifier = [
    aws_subnet.az1.id,
    aws_subnet.az2.id,
    aws_subnet.az3.id,
  ]

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.eks_cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
resource "aws_iam_instance_profile" "eks_node" {
  name = "${var.eks_cluster_name}-node-instance-profile"
  role = aws_iam_role.eks_node_role.name
}

resource "aws_eks_access_entry" "nodes" {
  cluster_name  = aws_eks_cluster.K8s_cluster.name
  principal_arn = aws_iam_role.eks_node_role.arn
  type          = "EC2_LINUX"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "${var.eks_cluster_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.eks_cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "az1" {
  subnet_id      = aws_subnet.az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "az2" {
  subnet_id      = aws_subnet.az2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "az3" {
  subnet_id      = aws_subnet.az3.id
  route_table_id = aws_route_table.public.id
}

# Add Elastic Container Registry

resource "aws_ecr_repository" "ecr" {
  name                 = var.ecr_name
  region               = var.region
  image_tag_mutability = "MUTABLE"


  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}

data "aws_caller_identity" "current" {}


# add Access Entry in EKS
resource "aws_eks_access_entry" "jenkins_build_agent" {
  cluster_name  = aws_eks_cluster.K8s_cluster.name
  principal_arn = "arn:aws:iam::718980965007:role/jenkins-agent-build-role"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins_build_agent_admin" {
  cluster_name  = aws_eks_cluster.K8s_cluster.name
  principal_arn = "arn:aws:iam::718980965007:role/jenkins-agent-build-role"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Add RDS
resource "random_password" "db_password" {
  length  = 20
  special = false
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name = "${var.eks_cluster_name}-db-subnets"
  subnet_ids = [
    aws_subnet.az1.id,
    aws_subnet.az2.id,
    aws_subnet.az3.id,
  ]
}

resource "aws_security_group" "rds_sg" {
  name   = "${var.eks_cluster_name}-rds-sg"
  vpc_id = aws_vpc.k8s_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.K8s_cluster.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.eks_cluster_name}-postgres"
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "devops_db"
  username               = "postgres"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  storage_encrypted      = true
}

