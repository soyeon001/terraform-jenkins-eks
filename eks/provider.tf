provider "aws" {
  region = "ap-northeast-2"
}

# 쿠버네티스의 리소스를 테라폼으로 관리하기 떄문에 정보를 알려줘야 됨
provider "kubernetes" {
  host                   = module.test-eks-cluster.cluster_endpoint #main에서 만든 것
  token                  = data.aws_eks_cluster_auth.default.token
  cluster_ca_certificate = base64decode(module.test-eks-cluster.cluster_certificate_authority_data)
}

provider "helm" {
  kubernetes {
    host                   = module.test-eks-cluster.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.default.token
    cluster_ca_certificate = base64decode(module.test-eks-cluster.cluster_certificate_authority_data)
  }
}