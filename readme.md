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
| Infrastructure        | Terraform, AWS (VPC, EKS, ECR, EC2, IAM/IRSA)     |
| Configuration mgmt    | Ansible                                           |
| Bootstrap automation  | GitHub Actions (`workflow_dispatch`)              |
| Container runtime     | Docker, Amazon ECR                                |
| Orchestration         | Kubernetes (EKS)                                  |
| CI / CD               | Jenkins (self-hosted, 1 master + 2 agents on EC2) |


 
---

## Prerequisites
 
Access to AWS is required for Terraform to provision infrastructure and for Jenkins to push images to ECR and deploy to EKS. At minimum you'll need:
 
- An AWS account with permissions to create VPC, EKS, ECR, EC2, and IAM resources
- AWS credentials (access key / secret key, or an IAM role) available to Terraform and Jenkins
- `kubectl`, `aws-cli`, and `terraform` installed locally for initial bootstrap and verification
> Detailed setup instructions (credential provisioning, `terraform init/plan/apply`, Jenkins bootstrap) will be added as each stage is implemented.


### Bootstrapping Jenkins
 
The Jenkins master + agents are stood up entirely through a manually-triggered GitHub Actions workflow (`workflow_dispatch`) — no local steps required. It runs `terraform apply` against `terraform-jenkins/`, waits for SSH to come up on the master, generates a dynamic Ansible inventory from the Terraform outputs, then runs the Ansible playbook to install Jenkins, configure the agents, and register them as nodes.
 
The workflow expects the following repository secrets:
 
| Secret                       | Purpose                                                   |
|-------------------------------|------------------------------------------------------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Terraform provider auth                     |
| `AWS_PUBLIC_KEY`               | SSH public key injected into the EC2 instances           |
| `SSH_KEY_B64`                  | Base64-encoded private key used to SSH into the master and, via `ProxyJump`, the agents |
| `JENKINS_DEFAULT_PASSWORD`     | Password set for the Jenkins `jenkins` admin account      |
| `GIT_PAT`                      | GitHub PAT stored as a Jenkins credential, used to raise the GitHub API rate limit for branch scanning |
 
> Further setup instructions (application infra `terraform init/plan/apply`, EKS access) will be added as later stages are implemented.
 
---
 
