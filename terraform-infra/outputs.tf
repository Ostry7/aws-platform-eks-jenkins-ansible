output "ecr_region" {
  value = aws_ecr_repository.ecr.region
}

output "ecr_account_id" {
  value = data.aws_caller_identity.current.account_id
}
