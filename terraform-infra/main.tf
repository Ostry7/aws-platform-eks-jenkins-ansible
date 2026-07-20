# create vpc for K8s cluster
resource "aws_vpc" "k8s_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames  =   true

  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_subnet" "az1" {
  vpc_id     = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "az1_subnet"
  }
}

resource "aws_subnet" "az2" {
  vpc_id     = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "az2_subnet"
  }
}

resource "aws_subnet" "az3" {
  vpc_id     = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "az3_subnet"
  }
}

resource "aws_eks_cluster" "K8s_cluster" {
  name = "K8s_cluster"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster.arn
  version  = "1.35"

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
  name = "eks-cluster-example"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
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