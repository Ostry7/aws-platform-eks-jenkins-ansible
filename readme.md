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
| Infrastructure        | Terraform, AWS (VPC, EKS, ECR, EC2, RDS, IAM/access entries) |
| Configuration mgmt    | Ansible                                        |
| Bootstrap automation  | GitHub Actions (`workflow_dispatch`)           |
| Container runtime     | Docker (multi-stage builds), Amazon ECR        |
| Orchestration         | Kubernetes (EKS)                               |
| CI / CD               | Jenkins (self-hosted, 1 master + 2 agents, multibranch pipelines via GitHub Branch Source) |
| Secrets management    | HashiCorp Vault (Kubernetes auth, dynamic PostgreSQL secrets engine) |
| Database              | Amazon RDS (PostgreSQL)                        |
| Package management    | Helm                                           |
| Application           | Python / Flask                                 |



 
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
 

## Roadmap:

### **Stage 1 - Infrastructure foundation with Terraform**

This workflow (`meta-pipeline.yml`) automates the entire process of standing up the Jenkins environment on AWS from scratch — from infrastructure to configuration. It's manually triggered (`workflow_dispatch`), giving full control over when provisioning runs.

## What it does, step by step
 
1. **Checkout + Terraform setup** – checks out the repo and installs the Terraform CLI.
2. **`terraform init` / `terraform apply`** – provisions the infrastructure in `eu-north-1`: a Jenkins master instance and two agents (build, infra). The SSH public key is passed in as a Terraform variable (`TF_VAR_public_key`) from a secret.
3. **Read Terraform outputs** – extracts the master's public IP and the agents' private IPs, exposing them as step outputs for later use in the job.
4. **SSH setup** – decodes the private key from a base64-encoded secret, sets correct permissions, and adds the master to `known_hosts`.
5. **Wait for SSH** – polls the master's SSH port until it responds (120s timeout), avoiding race conditions right after the instance boots.
6. **Copy SSH key to master (for ProxyJump)** – copies the private key onto the master itself, since the agents are only reachable through it (private IPs, no direct public access) — the master acts as a jump host.
7. **Generate dynamic Ansible inventory** – builds `hosts.yaml` on the fly using the IPs from Terraform. Agent entries include `ProxyJump=ubuntu@<master_ip>` so Ansible can reach them through the master over SSH.
8. **Install Ansible** – installs it on the GitHub Actions runner.
9. **Run the Ansible playbook** – executes `site.yml` against the generated inventory, passing in the Jenkins admin password and GitHub PAT as extra vars (both from secrets) for configuring Jenkins itself.
## Key design points
 
- **End-to-end automation**: one manual trigger takes you from empty AWS account to a fully configured Jenkins cluster (master + 2 agents).
- **No static IPs/inventory**: everything is derived dynamically from `terraform output`, so the pipeline survives instance replacement without manual updates.
- **ProxyJump pattern**: agents sit on private IPs; SSH access flows through the master, matching a real bastion-style network layout.
- **Secrets handling**: AWS credentials, SSH key (base64-encoded), Jenkins password, and GitHub PAT are all injected via GitHub Actions secrets — nothing hardcoded.

### **Stage 2 – Server configuration with Ansible**

This stage takes the raw EC2 instances provisioned in Stage 1 and turns them into a working Jenkins cluster: a fully unlocked, plugin-ready master and two purpose-built agents, all wired together and registered automatically. Driven by a single top-level playbook (`site.yml`) across four roles plus a final "register agents" play.

## Roles
 
### `jenkins-master`
- Installs Java 21, adds the Jenkins apt repo (with a stale-keyring cleanup step for idempotent reruns), installs and starts Jenkins.
- Unlocks Jenkins programmatically via `jenkins_script`: reads the auto-generated initial admin password, creates the real admin account, sets a security realm, and applies a `FullControlOnceLoggedInAuthorizationStrategy` (no anonymous read). Marks the setup wizard as completed so the first-run screen never shows up.
- Waits for Jenkins to respond on `/login` before continuing (retry loop, since restart/startup timing varies).
- Installs plugins (`blueocean`, `github`, `github-branch-source`, credentials plugins, `ssh-slaves`, branch build strategies) — but only the ones missing, by diffing against the currently installed plugin list first, so reruns don't force unnecessary restarts. Restarts Jenkins only if something actually changed.
- Generates an RSA key pair for the master (PEM format, for Trilead SSH library compatibility) used later to reach the agents.
- Stores the GitHub PAT as **two** separate Jenkins credentials: a username/password credential (for API rate-limit auth) and a secret-text credential (required by the GitHub Server config), then configures the GitHub plugin's server list to use it — this fixes GitHub API rate limiting on the multibranch jobs.
- Creates the `build-pipeline` and `infra-pipeline` multibranch jobs directly from XML job definitions checked into the repo (`Jenkins/build/init-job.xml`, `Jenkins/infra/init-job.xml`).
### `jenkins-agent-common` (both agents)
- Installs Java, creates the `jenkins` system user with a home directory, sets up `.ssh` and the agent working directory.
- Adds the master's public key (shared via `set_fact` from the master role) to the agent's `authorized_keys`, so the master can SSH in as the Jenkins launch mechanism requires.
### `jenkins-agent-build`
- Installs Docker, Terraform, AWS CLI v2, `kubectl`, Python, and `gettext-base` (for `envsubst`, used later in the CD pipeline for templating Kubernetes manifests).
- Adds `jenkins` to the `docker` group and enables the Docker daemon on boot.
### `jenkins-agent-infra`
- Installs Terraform, AWS CLI v2, `kubectl`.
- Grants the `jenkins` user passwordless sudo (validated via `visudo -cf`) — needed for infra-level operations this agent runs.
## Agent registration
 
A final play (still targeting the master) wires the agents into Jenkins itself:
- Adds the master's private key as an SSH credential (`jenkins-agent-ssh-key`), skipping creation if it already exists.
- Registers **build-agent** via `SSHLauncher` against the build agent's inventory host, with 2 executors and the `build` label.
- Registers **infra-agent** the same way, with 1 executor and the `terraform` label — matching the tools installed on each box.
Both node-creation scripts are idempotent (`if (Jenkins.instance.getNode(...) == null)`), so re-running the playbook won't duplicate nodes.
 
## Key design points
 
- **Everything scripted via Jenkins Groovy (`jenkins_script`)** rather than manual UI clicks — security realm, credentials, GitHub config, and node registration are all reproducible from code.
- **Idempotency throughout**: plugin installs, credential creation, and node registration all check current state before acting, so the playbook is safe to rerun.
- **Labels tie jobs to capability**: agents are labelled `build` and `terraform` so Jenkins pipeline stages can target the right tool-equipped node.
- **Master-as-bastion carries over from Stage 1**: the master's public key (generated here) is what lets it reach into the agents over SSH for the Jenkins launcher, same private-network pattern used for provisioning.
 
