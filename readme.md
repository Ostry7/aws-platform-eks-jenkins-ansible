## AWS EKS Platform

A production-style project deploying a containerized application to AWS Elastic Kubernetes Service (EKS), with infrastructure provisioned via Terraform, servers configured via Ansible, CI handled by a self-hosted Jenkins, and CD handled via GitOps (ArgoCD).

### Planned Architecture:
```
GitHub Repository
        │
        ▼
Jenkins (self-hosted on EC2, configured via Ansible)
        │
        ├──► Amazon ECR (image registry)
        │
        └──► ArgoCD (GitOps CD)
                    │
                    ▼
            EKS (Elastic Kubernetes Service)
                    │
                    ├── Deployment + HPA
                    ├── Ingress (nginx)
                    ├── Prometheus + Grafana (monitoring)
                    └── Velero (backup / DR to S3)
```
---


### Roadmap


- Stage 1 — Infrastructure foundation with Terraform (VPC, EKS, ECR, EC2 for Jenkins, IAM/IRSA)
- Stage 2 — Server configuration with Ansible (Jenkins master/agents, Docker, kubectl, aws-cli, hardening)
- Stage 3 — Application + Dockerfile + push to ECR
- Stage 4 — CI pipeline with Jenkins (Jenkinsfile, build, push to ECR)
- Stage 5 — CD with ArgoCD (GitOps, auto-deploy on manifest change)
- Stage 6 — Kubernetes manifests (Deployment, HPA, Ingress)
