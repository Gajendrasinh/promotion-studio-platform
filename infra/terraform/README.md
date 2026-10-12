# AWS infrastructure baseline

Do not apply without an approved account/environment/cost plan. This provisions three AZs, three NAT gateways, private EKS control plane and managed worker group, immutable ECR repositories, and encrypted multi-AZ RDS with Secrets Manager managed master password, PITR and deletion protection. Costs accrue immediately when applied. Terraform state backend/bucket/KMS/locking must already exist with restricted access; provide `-backend-config` from secured environment configuration.

```
terraform init -backend-config=/secure/path/backend.hcl
terraform fmt -check
terraform validate
terraform plan -var-file=/secure/path/environment.tfvars -out=/secure/path/reviewed.plan
```

No AWS resources were deployed during implementation. Kubernetes/EKS and RDS version variables intentionally require an environment owner to select region-supported versions rather than invent a current version. After deployment, bootstrap service databases and distinct service users using an audited administrative procedure; apps must never use the master credentials. Create secret-backed DATABASE_URLs with TLS (`sslmode=verify-full`). Supply MSK and ElastiCache with TLS/auth, subnet groups, private security groups and policy-approved sizing in a subsequent infrastructure module. Add ALB controller, External Secrets, EKS Pod Identity/CNI least-privilege identity, DNS/ACM, autoscaler, network policy enforcement and telemetry export before any public application deployment.

This baseline uses worker-role CNI permissions for first bootstrap; production must move them to a dedicated workload identity. Secrets Manager master rotation and service-user rotation need tested policies. AWS OIDC CI roles and private-network runner access must be provisioned independently. Review subnet CIDR and EKS policy scope against organizational standards.
