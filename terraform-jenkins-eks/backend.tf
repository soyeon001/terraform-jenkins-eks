terraform {
  backend "s3" {
    bucket = "soyun-eks-jenkins-terraform"
    key    = "jenkins/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
