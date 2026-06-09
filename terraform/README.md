# Terraform - observatory IaC (LocalStack)

Reproducible, modular Terraform that provisions a small cloud platform entirely locally against LocalStack (https://localstack.cloud/). No cloud account, no credentials, no keys - the AWS provider is pointed at the LocalStack edge port (http://localhost:4566) with dummy test/test credentials, the skip_* validation flags, and s3_use_path_style = true.

## What it provisions

| Module            | Resources                                                                                   |
| ----------------- | ------------------------------------------------------------------------------------------- |
| `modules/network` | VPC, 2 subnets (across 2 AZs), 1 shared security group                                       |
| `modules/platform`| ECR repository, CloudWatch log group, S3 artifacts bucket (versioned), IAM role for the Lambda, and a trivial **Lambda** (`src/handler.py`, zipped inline) as the deployable sample workload |

`main.tf` wires the two modules together; `variables.tf` / `outputs.tf` expose the knobs and the resulting names/ARNs.

## Layout

```
terraform/
|-- providers.tf         # aws provider -> LocalStack endpoints (s3, ec2, iam, ecr, logs, lambda, sts)
|-- variables.tf
|-- main.tf              # module wiring
|-- outputs.tf
`-- modules/
    |-- network/         # VPC + subnets + security group
    `-- platform/        # ECR + log group + S3 + IAM role + Lambda
        `-- src/handler.py
```

## Usage

Bring up LocalStack (the repo Makefile tf-up target does this for you), then:

```sh
cd terraform
terraform init
terraform apply
```

CI / offline validation (no LocalStack required):

```sh
terraform fmt -check
terraform init -backend=false
terraform validate
```

## Scoping note - emulated AWS via LocalStack

This stack targets LocalStack Community, which emulates a useful subset of AWS locally. Everything provisioned here (VPC/subnets/SG, IAM, ECR, CloudWatch log groups, S3, and a Lambda as the deployable sample resource) is supported by Community, so terraform apply works with Docker only.

**Real-AWS upgrade path.** Running an actual container workload on ECS/Fargate requires either LocalStack Pro or a real AWS account, so it is intentionally not part of this Community-scoped configuration - including it would break a plain terraform apply against Community. To promote this to real infrastructure:

1. Remove the `endpoints {}` block and the `skip_*` / dummy-credential settings from `providers.tf` so the provider talks to real AWS.
2. Add an `ecs`/`fargate` module (cluster + task definition referencing the `modules/platform` ECR image + service) alongside the existing modules.
3. Push the service image (see `service/Dockerfile`) to the ECR repository this config already creates, and point the ECS task definition at it.

The network and platform modules are written to carry over unchanged.

## Maintainer

This project is maintained by Yeshwanth Reddy Aleti.

**About the Developer**
Yeshwanth Reddy Aleti is a Network Engineer with over 4 years of experience in designing and supporting enterprise network infrastructures. With a focus on cloud networking, automation, and security, he leverages tools like Python, PowerShell, and Bash to build resilient and scalable environments.

Email: yeshwanth.ra61@gmail.com