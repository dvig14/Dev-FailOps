# 📚 FailOps Failure Catalog

> Auto-generated from `meta.yml` files.

<br>

## Terraform Failures

| ID | Title | Level | Tools | Description |
|----|-------|-------|-------|-------------|
| 01 | [state lock conflict](terraform/2-intermediate/02_state-lock-conflict) | Intermediate | Terraform + Minio + Consul | State lock → multiple people can't edit infra at the same time |
| 02 | [state drift](terraform/2-intermediate/01_state-drift) | Intermediate | Terraform + Minio | State drift → terraform don't know about changes outside it |
| 03 | [tfstate deletion](terraform/1-beginner/01_tfstate-deletion) | Beginner | Terraform + Minio | Deleted *.tfstate → loss of infra tracking |

