terraform {
  required_version = "~> 1.13.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "6.15.0" }
  }
  # Configure an encrypted remote backend using -backend-config in your environment.
  backend "s3" {}
}
provider "aws" {
  region = var.region
  default_tags { tags = { Project = "promotion-platform", Environment = var.environment } }
}
variable "region" {
  type    = string
  default = "ap-southeast-1"
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Use a separate dev, staging or production environment."
  }
}
variable "eks_version" {
  type        = string
  description = "Set a currently supported EKS version after checking AWS support dates."
}
variable "database_engine_version" {
  type        = string
  description = "Set a currently supported RDS PostgreSQL 17 minor after checking the region."
}
variable "administrator_role_arn" {
  type        = string
  description = "Existing platform administration IAM role for EKS access; no embedded credentials."
}
data "aws_availability_zones" "available" { state = "available" }
locals {
  name     = "promotions-${var.environment}"
  zones    = slice(data.aws_availability_zones.available.names, 0, 3)
  services = toset(["api-gateway", "promotion-service", "rule-engine-service", "customer-service", "eligibility-service", "redemption-service", "frontend"])
}
resource "aws_vpc" "platform" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}
resource "aws_internet_gateway" "platform" { vpc_id = aws_vpc.platform.id }
resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc.platform.id
  availability_zone = local.zones[count.index]
  cidr_block        = cidrsubnet(aws_vpc.platform.cidr_block, 8, count.index)
  tags              = { "kubernetes.io/role/elb" = "1" }
}
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.platform.id
  availability_zone = local.zones[count.index]
  cidr_block        = cidrsubnet(aws_vpc.platform.cidr_block, 8, 10 + count.index)
  tags              = { "kubernetes.io/role/internal-elb" = "1" }
}
resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"
}
resource "aws_nat_gateway" "platform" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.platform]
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.platform.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.platform.id
  }
}
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.platform.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.platform[count.index].id
  }
}
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
resource "aws_iam_role" "cluster" {
  name               = "${local.name}-eks"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_eks_cluster" "platform" {
  name                      = local.name
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.eks_version
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  access_config { authentication_mode = "API" }
  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = false
  }
  depends_on = [aws_iam_role_policy_attachment.cluster]
}
resource "aws_eks_access_entry" "administrator" {
  cluster_name  = aws_eks_cluster.platform.name
  principal_arn = var.administrator_role_arn
  type          = "STANDARD"
}
resource "aws_eks_access_policy_association" "administrator" {
  cluster_name  = aws_eks_cluster.platform.name
  principal_arn = var.administrator_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
  depends_on = [aws_eks_access_entry.administrator]
}
resource "aws_iam_role" "node" {
  name               = "${local.name}-nodes"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "node" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy"])
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}
resource "aws_eks_node_group" "platform" {
  cluster_name    = aws_eks_cluster.platform.name
  node_group_name = local.name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = ["m6i.large"]
  scaling_config {
    desired_size = 3
    min_size     = 3
    max_size     = 9
  }
  update_config { max_unavailable = 1 }
  depends_on = [aws_iam_role_policy_attachment.node]
}
resource "aws_security_group" "database" {
  name   = "${local.name}-database"
  vpc_id = aws_vpc.platform.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.platform.vpc_config[0].cluster_security_group_id]
  }
}
resource "aws_db_subnet_group" "platform" {
  name       = local.name
  subnet_ids = aws_subnet.private[*].id
}
resource "aws_db_instance" "platform" {
  identifier                  = local.name
  engine                      = "postgres"
  engine_version              = var.database_engine_version
  instance_class              = "db.t4g.medium"
  allocated_storage           = 50
  max_allocated_storage       = 250
  storage_encrypted           = true
  username                    = "platform_admin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.platform.name
  vpc_security_group_ids      = [aws_security_group.database.id]
  publicly_accessible         = false
  multi_az                    = true
  backup_retention_period     = 14
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "${local.name}-final"
  auto_minor_version_upgrade  = true
}
resource "aws_ecr_repository" "service" {
  for_each             = local.services
  name                 = "${local.name}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}
output "cluster_name" { value = aws_eks_cluster.platform.name }
output "database_endpoint" { value = aws_db_instance.platform.address }
output "master_secret_arn" {
  value     = aws_db_instance.platform.master_user_secret[0].secret_arn
  sensitive = true
}
output "repository_urls" { value = { for name, r in aws_ecr_repository.service : name => r.repository_url } }
