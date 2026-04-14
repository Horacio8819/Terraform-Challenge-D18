# The Importance of Manual Testing in Terraform

## 📌 Overview
This project demonstrates a structured approach to **manual testing in Terraform** using a webserver cluster deployed on AWS.

While automated testing validates configuration and pipelines, manual testing ensures that infrastructure behaves correctly in real-world conditions. This README documents the testing strategy, execution process, results, and key lessons learned.

---

## 🎯 Why Manual Testing Matters
Automation alone is not enough. Terraform can successfully provision infrastructure that still fails functionally.

Manual testing helps to:
- Validate real system behavior
- Detect configuration drift and hidden issues
- Ensure infrastructure works end-to-end
- Build confidence before production deployment

---

## 🧪 Manual Testing Checklist

### 1. Provisioning Verification
- `terraform init` completes without errors
- `terraform validate` passes
- `terraform plan` shows expected resources
- `terraform apply` completes successfully

### 2. Resource Correctness
- Resources visible in AWS Console
- Names, tags, and regions match variables
- Security group rules match configuration exactly

### 3. Functional Verification
- ALB DNS resolves
- `curl http://<alb-dns>` returns expected response
- Instances pass health checks
- Auto Scaling Group replaces failed instances

### 4. State Consistency
- `terraform plan` shows **No changes** after apply
- Terraform state matches actual AWS resources

### 5. Regression Checks
- Small configuration change reflects correctly in `terraform plan`
- No unexpected changes appear
- Clean plan after re-apply

---

## 📊 Test Execution & Results

### ✅ Pass Example
**Test:** ALB DNS resolves and returns expected response  
**Command:**
```bash
curl -s http://<alb-dns>
