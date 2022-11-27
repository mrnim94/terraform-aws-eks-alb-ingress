# Terraform Kubernetes Provider
provider "kubernetes" {
  host = var.cluster_endpoint 
  cluster_ca_certificate = base64decode(var.eks_cluster_certificate_authority_data)
  token = data.aws_eks_cluster_auth.cluster.token
}