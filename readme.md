## AWS EKS Platform

A production-style project deploying a containerized application to AWS Elastic Kubernetes Service (EKS), with infrastructure provisioned via Terraform, servers configured via Ansible, CI/CD handled by a self-hosted Jenkins.

### Planned Architecture:
```
GitHub Repository
        │
        ▼
Jenkins (self-hosted on EC2, configured via Ansible)
        │
        ├──► Amazon ECR (image registry)
        │
        ▼
        EKS (Elastic Kubernetes Service)
                │
                ──► Deployment + HPA

```
---


### Roadmap


- Stage 1 — Infrastructure foundation with Terraform (VPC, EKS, ECR, EC2 for Jenkins, IAM/IRSA)
- Stage 2 — Server configuration with Ansible (Jenkins master/agents, Docker, kubectl, aws-cli, hardening)
- Stage 3 — Application + Dockerfile + push to ECR
- Stage 4 — CI/CD pipeline with Jenkins (Jenkinsfile, build, push to ECR)
- Stage 5 — CD with ArgoCD (GitOps, auto-deploy on manifest change)
- Stage 6 — Kubernetes manifests (Deployment)


## Tech Stack
 
|        Layer        |                     Tools                     |
|:--------------------:|:----------------------------------------------:|
| Infrastructure        | Terraform, AWS (VPC, EKS, ECR, EC2, IAM/IRSA)  |
| Configuration mgmt    | Ansible                                        |
| Container runtime     | Docker, Amazon ECR                             |
| Orchestration         | Kubernetes (EKS)                               |
| CI / CD               | Jenkins (self-hosted, master/agents on EC2)    |
 
---

## Prerequisites
 
Access to AWS is required for Terraform to provision infrastructure and for Jenkins to push images to ECR and deploy to EKS. At minimum you'll need:
 
- An AWS account with permissions to create VPC, EKS, ECR, EC2, and IAM resources
- AWS credentials (access key / secret key, or an IAM role) available to Terraform and Jenkins
- `kubectl`, `aws-cli`, and `terraform` installed locally for initial bootstrap and verification
> Detailed setup instructions (credential provisioning, `terraform init/plan/apply`, Jenkins bootstrap) will be added as each stage is implemented.
