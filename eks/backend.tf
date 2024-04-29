terraform {
  backend "s3" {
    bucket = "soyun-eks-jenkins-terraform"
    key = "eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}