# VULN: EKS cluster with intentionally misconfigured security settings

# VULN: EKS-001 — Public API server endpoint without CIDR restriction
resource "aws_eks_cluster" "vulnmcp" {
  name    = "${var.project_name}-cluster"
  version = "1.27"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    # VULN: EKS-001 — Public endpoint enabled
    endpoint_private_access = false
    endpoint_public_access  = true
    # MISSING: public_access_cidrs = ["10.0.0.0/8"]
    # Without restriction, API is accessible from anywhere

    subnet_ids = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  }

  # VULN: EKS-002 — No encryption of Kubernetes secrets
  # Should use envelope encryption with AWS KMS
  encryption_config {
    resources = [] # Empty - secrets not encrypted
    provider {
      key_arn = null
    }
  }

  # VULN: LOGGING-001 — Audit logging not enabled
  enabled_cluster_log_types = []

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = var.common_tags
}

# VULN: EKS-003 — Node group with overprivileged IAM role
resource "aws_eks_node_group" "vulnmcp" {
  cluster_name    = aws_eks_cluster.vulnmcp.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = module.vpc.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  # VULN: EKS-004 — No IMDSv2 requirement (vulnerable to SSRF)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional" # VULN: Should be "required"
    http_put_response_hop_limit = 1
  }

  tags = var.common_tags

  depends_on = [aws_iam_role_policy_attachment.node_group_basic]
}

# VULN: IAM-001 — Node role with AdministratorAccess
resource "aws_iam_role" "node_group_role" {
  name = "${var.project_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.common_tags
}

# VULN: IAM-001 — Attaching AdministratorAccess to node role
resource "aws_iam_role_policy_attachment" "node_group_basic" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.node_group_role.name
}

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
