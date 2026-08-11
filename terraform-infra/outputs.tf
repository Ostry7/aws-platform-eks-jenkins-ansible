output "ecr_region" {
  value = aws_ecr_repository.ecr.region
}

output "ecr_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "ecr_name" {
  value = aws_ecr_repository.ecr.name
}

output "eks_cluster_name" {
  value = aws_eks_cluster.K8s_cluster.name
}

output "db_host" {
  value = aws_db_instance.postgres.address
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
  }

output "eks_endpoint"{
  value = aws_eks_cluster.K8s_cluster.endpoint
}