#vpc
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks-vpc"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.azs.names
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  enable_vpn_gateway = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support = true

  #Load balancer controller
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}




# eks
module "test-eks-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "test-eks-cluster"
  cluster_version = "1.29"

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  enable_irsa = true




  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size = 50
  }

  eks_managed_node_groups = {
    general = {
      min_size     = 1
      max_size     = 10
      desired_size = 1

      labels = { role = "general"}
      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
    }
    spot = {
      min_size     = 1
      max_size     = 10
      desired_size = 1

      labels = { role = "spot"}
      instance_types = ["m5.large"]
      capacity_type  = "SPOT"
      taints = [{ #제한
        key = "market"
        value = "spot"
        effect = "NO_SCHEDULE"
      }]
    }
    
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# AWS Load Balancer controller 설치
# EKS LoadBalancer -> NLB, ingress -> ALB 
## IRSA 

module "aws_load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

# 클러스터 생성해서 penid connect 공급자정보가 생기면 aws iam에 등록해줘야 쿠버네티스와  aws 연동
  oidc_providers = {
    ex = {
      provider_arn               = module.test-eks-cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
## 설치
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  
  # 옵션
  set {
    name  = "clusterName"
    value = module.test-eks-cluster.cluster_name
  }

  set {
    name  = "serviceAccount.name" #irsa
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }

}

# Argo CD :배포관리툴 설치
resource "helm_release" "argocd" {
  name = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  values     = [file("argocd-value.yaml")]
  depends_on = [helm_release.aws_load_balancer_controller]
}

