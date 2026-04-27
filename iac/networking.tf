# VULN: Overly permissive security groups and network configuration

# VULN: SG-001 — Security group allows 0.0.0.0/0 on all ports
resource "aws_security_group" "vulnmcp" {
  name   = "${var.project_name}-sg"
  vpc_id = module.vpc.vpc_id

  # VULN: SG-001 — Inbound rule allows all traffic from anywhere
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Should be restricted
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]  # Should be restricted
  }

  # VULN: SG-001 — Outbound allows all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}

# VULN: NET-001 — VPC Flow Logs disabled (no network audit trail)
# In main.tf, enable_flow_log = false

# VULN: NET-002 — Public subnets used for production workloads
# Should have private subnets with NAT gateway for secure egress
# Currently: public_subnets are used directly for node group

# VULN: NET-003 — No NAT Gateway
# Nodes have direct internet routing
# Should route through NAT gateway for security

# TODO: Add ALB/NLB configuration with public exposure
