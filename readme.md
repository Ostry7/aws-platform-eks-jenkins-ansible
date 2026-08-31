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

# **Stage 1 - Infrastructure foundation with Terraform**

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

# **Stage 2 – Server configuration with Ansible**

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
 
# **Stage 3 – Application + Dockerfile**

A multi-stage `Dockerfile` builds the Flask application into a small, production-ready image, which the `build-pipeline` Jenkins job builds and pushes to ECR.

## Dockerfile breakdown
 
### Build stage (`build-env`)
- Based on `python:3.14.3-alpine` — small base image.
- Installs `gcc`, `musl-dev`, `libffi-dev` — Alpine's minimal libc (musl) means Python packages with native C extensions need a compiler and headers to build from source; these aren't needed at runtime.
- Copies only `requirements.txt` first and installs dependencies with `pip install --user`, so Docker's layer cache can skip the (usually slow) dependency install step when only application code changes.
### Final stage
- Fresh `python:3.14.3-alpine` base — no build toolchain, keeping the final image small and reducing attack surface.
- Copies **only** the installed packages (`/root/.local`) from the build stage — the compiler and headers from the build stage are left behind entirely.
- Copies in `app.py`.
- Adds `/root/.local/bin` to `PATH` so user-installed console scripts are reachable.
- Exposes port `5000` (Flask's default) and runs the app directly with `python app.py`.
## Key design points
 
- **Multi-stage build**: keeps build-only dependencies (compiler, headers) out of the final image — smaller size, smaller attack surface.
- **Alpine base**: minimizes image size, at the cost of needing to explicitly install build tooling for any C-extension packages.
- **Layer-cache-friendly ordering**: `requirements.txt` is copied and installed before the rest of the app code, so dependency layers are only rebuilt when dependencies actually change.
- **Built and pushed by the build pipeline**: this Dockerfile is consumed by the `build-agent`'s Jenkins pipeline, which builds the image and pushes it to ECR as part of the CI/CD flow.

# **Stage 4 – CI/CD pipeline with Jenkins**

Two multibranch pipeline jobs — `main-build-pipeline` and `main-infra-pipeline` — are auto-discovered from GitHub (via the `github-pat` credential set up in Stage 2) and defined by `Jenkinsfile`s at `Jenkins/build/Jenkinsfile` and `Jenkins/infra/Jenkinsfile` respectively. Both use branch + PR discovery traits, so any branch or pull request automatically gets a pipeline run.

## Build pipeline (`build-agent`)
 
Builds, pushes, and deploys the application image.
 
1. **Indexing guard** – if the run was triggered by branch indexing (not a real push), it just sleeps for 10 minutes instead of running the full pipeline, avoiding redundant work while ECR/EKS state is settled elsewhere.
2. **Checkout** – pulls the repo from GitHub.
3. **Start Docker daemon** – launches `dockerd` manually and waits for it, since the agent doesn't run Docker as a system service.
4. **Build image** – reads the ECR repo name from Terraform output (`terraform-infra`), tags the image `1.<BUILD_NUMBER>`, and builds it from the `app/` directory.
5. **Login to ECR** – pulls region and account ID from Terraform outputs, authenticates Docker against ECR using `aws ecr get-login-password`.
6. **Push image** – tags and pushes the image to the ECR repo.
7. **Create DB secret** – fetches the EKS cluster name and DB host/password from Terraform, updates the kubeconfig, applies the namespace/service account manifests, and creates (or updates) a `db-credentials` Kubernetes secret via `kubectl create --dry-run=client | kubectl apply`, keeping the operation idempotent.
8. **Prod deploy to EKS** – builds the full image reference, updates kubeconfig, then uses `envsubst` to template `k8s/deployment.yaml` with the image tag before applying it, applies the service manifest, and waits on rollout status (2 min timeout).
9. **Init DB schema** – spins up a temporary `postgres:16` pod, waits for it to be ready, copies `init-db.sql` into it, runs it against the database with `psql`, then deletes the pod — a disposable job runner pattern for one-off DB initialization.
## Infra pipeline (`infra-agent`)
 
Applies infrastructure changes and keeps Vault/Helm configured.
 
1. **Checkout** – pulls the repo.
2. **Terraform init** – formats and initializes the `terraform-infra` working directory.
3. **Terraform apply** – applies infra changes, then reads back the ECR region and EKS cluster name as outputs.
4. **Configure kubectl** – a verbose diagnostic stage (`set -eux`, AWS identity, kubeconfig, EKS token, `kubectl get nodes -v=8`) that updates the kubeconfig for this workspace and confirms cluster connectivity before proceeding.
5. **Install Helm** – adds Helm's apt repo with GPG key fingerprint verification (explicit key-ID check to guard against a compromised mirror), then installs it via apt.
6. **Install HashiCorp Vault** – adds the HashiCorp Helm repo and installs (or upgrades) Vault into the `vault` namespace in dev mode, with the Vault Agent Injector enabled. On upgrade, first removes the old mutating webhook to avoid stale webhook conflicts.
7. **Install Vault CLI** – adds HashiCorp's apt repo and installs the `vault` CLI on the agent.
8. **Configure Vault Kubernetes Auth** – port-forwards to the in-cluster Vault service, enables the Kubernetes auth method (if not already enabled), points it at the in-cluster API server, writes an `app-policy` granting read access to dynamic Postgres credentials, and binds that policy to a `app-role` scoped to the `myapp-sa` service account in the `prod` namespace.
9. **Set database password rotation** – re-applies Terraform to pull fresh DB outputs, enables Vault's `database` secrets engine at `postgres/` (if not already enabled), configures the Postgres connection plugin with admin credentials, and defines the `app-role` creation statements (dynamic role creation, grants on tables/sequences/schema) that Vault uses to hand out short-lived DB credentials to the app.
## Job definitions (`init-job.xml`)
 
Both jobs are `WorkflowMultiBranchProject`s created from XML in Stage 2 (via `jenkins_job`). Key shared configuration:
- **Source**: `GitHubSCMSource` pointed at `Ostry7/aws-platform-eks-jenkins-ansible`, authenticated with the `github-pat` credential.
- **Traits**: branch discovery + origin/fork PR discovery, so pushes and PRs both trigger builds.
- **Orphaned item strategy**: dead branches are pruned automatically, keeping the job list clean as branches are merged/deleted.
- **Factory**: each project factory points at its own `Jenkinsfile` path (`Jenkins/build/Jenkinsfile` / `Jenkins/infra/Jenkinsfile`), so both pipelines live in the same repo but run independent logic.
## Key design points
 
- **Separation of concerns**: build/push/deploy logic and infra/Vault/Helm logic are split into two independent pipelines with separate agent labels, matching the tool split from Stage 2.
- **Terraform as the source of truth for runtime values**: both pipelines read ECR/EKS/DB connection details from `terraform output` rather than hardcoding them, keeping infra and pipeline config in sync.
- **Dynamic secrets via Vault**: the app doesn't get static DB credentials — Vault issues short-lived Postgres roles per the `app-role` policy, reducing the blast radius of a leaked credential.
- **Idempotent Kubernetes operations**: secret creation and Helm install/upgrade both check current state first, so pipeline reruns don't fail on "already exists" errors.
- **Disposable job runner for DB init**: rather than baking schema init into the app image, a throwaway `psql` pod handles it and is deleted immediately after.
