# Day 18 — Automated testing of Terraform code

[![Terraform Tests](https://github.com/nahorfelix/terraform-challenge-day18/actions/workflows/terraform-test.yml/badge.svg?branch=main)](https://github.com/nahorfelix/terraform-challenge-day18/actions/workflows/terraform-test.yml)

**30-Day Terraform Challenge** · *Terraform: Up & Running* — **Chapter 9** (automated tests: unit, integration, end-to-end, CI/CD)

This repository implements three layers of testing against the **webserver cluster** module (`modules/services/webserver-cluster`), plus a GitHub Actions workflow.

### CI notes

- **Ubuntu / `terraform init`:** If the provider lock file was generated only on Windows, add Linux hashes locally with `terraform providers lock -platform=linux_amd64` or rely on the workflow step that runs the same command on GitHub-hosted runners.
- **Secrets:** Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` under **Settings → Secrets and variables → Actions** so `terraform test` (plan against real AWS APIs) and Terratest can run. Without them, the unit job runs **`terraform validate` only** and stays green; Terratest is skipped on push.

## Chapter 9 — map tests to this stack

| Layer | What it proves here |
|--------|---------------------|
| **Unit** (`terraform test`) | Planned resources match variables: ASG name, instance type, app port on the instance security group rule — **no AWS spend**, `command = plan`. |
| **Integration** (Terratest) | Real **apply** in default VPC, HTTP **200** from the ALB, then **destroy**. |
| **End-to-end** (Terratest) | Same deploy, plus assertions on **vpc_id**, **subnet_ids**, **alb_dns_name**, **target_group_arn**, and HTML body containing the **cluster name** (full path through LB to user-data). |

Integration tests assert **reachability**; E2E adds **multi-output** and **content** checks. A larger org might chain a separate VPC module; this module already includes default VPC networking + ALB + ASG + app, so one apply is the “stack” under test.

## Prerequisites

- **Terraform** ≥ 1.6 (`terraform test`)
- **Go** ≥ 1.21 (Terratest)
- **AWS CLI** configured with permissions to create EC2, ELB, ASG, IAM-related resources in **us-east-1** (default VPC must exist)

## Lab checklist (course)

- [ ] **Read** Chapter 9 through *Other Testing Approaches*
- [ ] **Lab 1:** Import existing infrastructure (your provider lab / account)
- [ ] **Lab 2:** Terraform Cloud (org/workspace as instructed)

## Unit tests (native Terraform)

```bash
cd modules/services/webserver-cluster
terraform init -input=false
terraform test
```

Tests live in `webserver_cluster_test.tftest.hcl`. The module has **no** `provider` block (reusable); the test file supplies `provider "aws"`.

## Integration & E2E tests (Terratest)

Tests apply the **fixture** at `test/fixtures/default`, which wraps the module with a root `provider "aws"`.

```bash
cd test
go test -v -timeout 45m ./...
```

- **Cost / time:** ~5–15 minutes per test; two tests can run in parallel (`t.Parallel()`). Always **`defer terraform.Destroy`**.

## CI/CD (GitHub Actions)

Workflow: `.github/workflows/terraform-test.yml`

| Trigger | Job |
|---------|-----|
| **Pull request** to `main` | `unit-tests` — `terraform test` |
| **Push** to `main` | `unit-tests` then `integration-tests` — `go test` |

**Secrets** (repo → Settings → Secrets):

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Use a **least-privilege** IAM user or OIDC-to-AWS in production. **Unit tests** still call AWS data sources during `plan`, so CI needs valid credentials unless you refactor to mock providers.

Fork PRs do not receive secrets; workflow steps may fail until you add secrets on your fork.

