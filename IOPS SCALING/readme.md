# Atlas Terraform IOPS Scaling Test

> [!WARNING]
> # COST AND RESPONSIBILITY DISCLAIMER
>
> This repository contains an example Terraform configuration for creating and modifying MongoDB Atlas infrastructure.
>
> **Running this script is the sole responsibility of the person or team using it.**
>
> **Using this script may create, modify, scale, or delete MongoDB Atlas clusters and can directly increase MongoDB Atlas costs.**
>
> Review every `terraform plan` carefully before running `terraform apply`.
>
> Do not run this against production environments unless you fully understand the operational, availability, and cost impact.

> [!IMPORTANT]
> # NOT AN OFFICIAL MONGODB PRODUCT
>
> This repository is **not an official MongoDB product**.
>
> It is **not maintained, supported, reviewed, or endorsed by the MongoDB product or engineering teams**.
>
> Use it only as a reference, demo, or lab example.

## Overview

This repository provides a minimal Terraform example for creating and modifying a MongoDB Atlas cluster using the MongoDB Atlas Terraform Provider.

The goal is to test moving a cluster between two states:

- **Baseline state:** standard/default IOPS
- **Scaled state:** larger cluster tier with Provisioned IOPS

The Terraform configuration is intentionally generic and does not hardcode any real customer, project, or production cluster details.

## Repository contents

```text
.
├── README.md
├── main.tf
└── .gitignore
```

## What Terraform manages

Terraform manages one MongoDB Atlas cluster through the `mongodbatlas_advanced_cluster` resource.

The cluster is controlled through these variables:

| Variable | Purpose |
|---|---|
| `project_id` | Atlas Project ID where the cluster will be created or managed |
| `cluster_name` | Name of the Atlas cluster |
| `provider_name` | Cloud provider, for example `AWS` |
| `region_name` | Cloud provider region, for example `US_EAST_1` |
| `baseline_instance_size` | Cluster tier used for the baseline state |
| `scaled_instance_size` | Cluster tier used for the scaled state |
| `scaled_disk_iops` | Provisioned IOPS value used in the scaled state |
| `target_state` | Desired state: `baseline` or `scaled` |

## Expected behavior

The configuration supports two states:

```text
baseline = baseline_instance_size + standard/default IOPS
scaled   = scaled_instance_size + Provisioned IOPS + scaled_disk_iops
```

Example:

```text
baseline = M80 + standard/default IOPS
scaled   = M140 + Provisioned IOPS + 32000 IOPS
```

Actual behavior depends on the values you configure and on the limits supported by MongoDB Atlas for your cloud provider, region, cluster tier, storage size, and IOPS configuration.

## Prerequisites

Install Terraform:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

Optional but useful:

```bash
brew install jq
brew install mongodb-atlas-cli
```

Validate Terraform is installed:

```bash
terraform -version
```

## Atlas authentication

Authenticate to Atlas using API keys.

The MongoDB Atlas Terraform Provider expects these environment variables:
Follow this tutorial to get API keys
[MongoDB API KEYS](https://www.mongodb.com/docs/atlas/configure-api-access/?interface=atlas-ui&programmatic-access=api-key)

```bash
MONGODB_ATLAS_PUBLIC_KEY
MONGODB_ATLAS_PRIVATE_KEY
```


Validate that the variables are present without printing secrets:

```bash
echo "public key length: ${#MONGODB_ATLAS_PUBLIC_KEY}"
echo "private key length: ${#MONGODB_ATLAS_PRIVATE_KEY}"
```

Both values should be greater than `0`.

## Configure the target Atlas project and cluster

Create a local `terraform.tfvars` file.

Do not commit this file.

```hcl
project_id   = "YOUR_ATLAS_PROJECT_ID"
cluster_name = "YOUR_CLUSTER_NAME"

provider_name = "AWS"
region_name   = "US_EAST_1"

baseline_instance_size = "M80"
scaled_instance_size   = "M140"
scaled_disk_iops       = 32000
```

Replace `YOUR_ATLAS_PROJECT_ID` with the Atlas Project ID where the cluster should be created or managed.

Replace `YOUR_CLUSTER_NAME` with the name of the cluster Terraform should create or manage.

Example:

```hcl
project_id   = "64abc1234567890example"
cluster_name = "Cluster0"
```

## Create the Terraform configuration

Create a `main.tf` file using the Terraform configuration provided in this repository.

## Create `.gitignore`

Recommended `.gitignore`:

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Local environment files
.env
.env.*


```

Note: `.terraform.lock.hcl` is intentionally not ignored. In a real repository, it is usually better to commit it so the provider version is reproducible.

## Initialize Terraform

Run:

```bash
terraform init
```

This downloads the MongoDB Atlas Terraform Provider.

## Review the baseline plan

The default `target_state` is `baseline`.

Run:

```bash
terraform plan -var="target_state=baseline"
```

Review the output carefully before applying.

## Create or apply baseline state

Run:

```bash
terraform apply -var="target_state=baseline"
```

Expected baseline state:

```text
baseline_instance_size
standard/default IOPS
no explicit disk_iops value
```

Example:

```text
M80
standard/default IOPS
disk_iops not explicitly configured
```

## Scale up

Run:

```bash
terraform plan -var="target_state=scaled"
```

Review the output carefully.

Then apply:

```bash
terraform apply -var="target_state=scaled"
```

Expected scaled state:

```text
scaled_instance_size
Provisioned IOPS
scaled_disk_iops
```

Example:

```text
M140
Provisioned IOPS
32000 IOPS
```

## Scale down

Run:

```bash
terraform plan -var="target_state=baseline"
```

Review the output carefully.

Then apply:

```bash
terraform apply -var="target_state=baseline"
```

Expected final state:

```text
baseline_instance_size
standard/default IOPS
no explicit disk_iops value
```

Example:

```text
M80
standard/default IOPS
disk_iops not explicitly configured
```

## Validate cluster state

Using Atlas CLI:

```bash
atlas clusters describe YOUR_CLUSTER_NAME \
  --projectId YOUR_ATLAS_PROJECT_ID \
  -o json | jq '.replicationSpecs[].regionConfigs[].electableSpecs | {instanceSize, nodeCount, ebsVolumeType, diskIOPS}'
```

Replace:

```text
YOUR_CLUSTER_NAME
YOUR_ATLAS_PROJECT_ID
```

with your actual cluster name and Atlas Project ID.

Expected scaled output pattern:

```json
{
  "instanceSize": "M140",
  "nodeCount": 3,
  "ebsVolumeType": "PROVISIONED",
  "diskIOPS": 32000
}
```

Expected baseline output pattern:

```json
{
  "instanceSize": "M80",
  "nodeCount": 3,
  "ebsVolumeType": "STANDARD",
  "diskIOPS": null
}
```

Actual values depend on the variables configured in `terraform.tfvars`.

## Watch cluster modifications

Using Atlas CLI:

```bash
atlas clusters watch YOUR_CLUSTER_NAME \
  --projectId YOUR_ATLAS_PROJECT_ID
```

## Destroy the cluster

Only run this if you want Terraform to delete the cluster.

```bash
terraform destroy
```

Review the destroy plan carefully before confirming.

## Security notes

- Do not commit API keys, client secrets, tokens, connection strings, or Terraform state files.
- Use environment variables for credentials.
- Keep `terraform.tfvars` local because it may contain project-specific information.
- The `terraform.tfstate` file can contain sensitive metadata and should not be committed.
- Rotate any credentials that were accidentally exposed.
- Do not paste real credentials into tickets, chats, documents, or public repositories.

## Operational notes

- Scaling Atlas clusters is not immediate.
- Treat scaling as an asynchronous operation and monitor until modifications complete.
- Provisioned IOPS limits depend on cloud provider, region, tier, storage size, and Atlas-supported limits.
- If `scaled_disk_iops` is rejected, adjust the cluster tier, storage configuration, or IOPS value according to Atlas limits.
- This configuration is intentionally minimal and may not represent all production settings required by your environment.
- Before using this in a production-like environment, review networking, backups, maintenance windows, MongoDB version, disk size, tags, termination protection, alerting, and organizational governance requirements.

## Suggested workflow

Use this flow for a clean test:

```bash
terraform init

terraform plan -var="target_state=baseline"
terraform apply -var="target_state=baseline"

terraform plan -var="target_state=scaled"
terraform apply -var="target_state=scaled"

terraform plan -var="target_state=baseline"
terraform apply -var="target_state=baseline"
```

Destroy only if you want to delete the cluster:

```bash
terraform destroy
```