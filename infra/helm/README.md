# Deployment baseline

Install into an environment-specific namespace after provisioning externally managed data and identity services. For every service, create `<service>-database` via an external secret manager with DATABASE_URL, DATABASE_USERNAME, DATABASE_PASSWORD. The gateway/eligibility include shared persistence infrastructure in this initial slice and also require a database. Production database users must be distinct and scoped to their service.

```
helm lint promotion-platform --set imageRepository=example.ecr --set imageTag=reviewed-sha --set issuer=https://identity.example/realms/promotion --set kafkaBootstrap=private-broker:9092
helm upgrade --install promotions promotion-platform --namespace promotions-dev --create-namespace --values /secure/path/environment-values.yaml --wait --timeout 5m
```

No ingress is created by default. Add a reviewed ALB/Gateway API resource in the environment overlay, ACM certificate and DNS. Label the ingress controller namespace `promotion-ingress=true`. This baseline limits pod ingress to platform pods and the gateway ingress controller; add scoped monitoring ingress and egress policies for your managed DB/Kafka/OIDC/OTLP networks. Configure CNI network-policy enforcement explicitly. No Kubernetes API permissions are granted to these service accounts. Add EKS Pod Identity/IRSA bindings only for actual required cloud access.

Probe endpoints must be accessible internally; admin metrics need a secret-backed identity. Use `helm rollback promotions <revision> --wait` only if database compatibility allows it. Images, IAM, TLS, secrets, dependency availability and probes require deployment testing before approval.
