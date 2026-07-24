output "ecr_region"{
    value = aws_ecr_repository.ecr.region
}

output "ecr_account_id"{
    value = aws_ecr_repository.ecr.id
}