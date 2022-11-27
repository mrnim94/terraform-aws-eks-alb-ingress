# terraform-aws-eks-alb-ingress

main.tf
```hcl
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "backend-terraform-250887682577"
    key    = "infra-structure/aws-3/eks/terraform.tfstate"
    region = var.aws_region
  }
}

module "eks-alb-ingress" {
  source  = "mrnim94/eks-alb-ingress/aws"
  version = "1.0.7"

  aws_region = var.aws_region
  environment = var.environment
  business_divsion = var.business_divsion

  eks_cluster_certificate_authority_data = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  eks_cluster_endpoint = data.terraform_remote_state.eks.outputs.cluster_endpoint
  eks_cluster_id = data.terraform_remote_state.eks.outputs.cluster_id
  aws_iam_openid_connect_provider_arn = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  vpc_id = data.terraform_remote_state.eks.outputs.vpc_id
}
```

```hcl
Outputs:

cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSRlgvZndHRmMKeU13PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
cluster_endpoint = "https://54BDECE91CB74A3682E45D44CB7533CE.gr7.us-west-2.eks.amazonaws.com"
cluster_id = "devops-nimtechnology"
oidc_provider_arn = "arn:aws:iam::250887682577:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/54BDECE91CB74A3682E45D44CB7533CE"
vpc_id = "vpc-0cca8eb1697887172"
```

Deployment

```yaml
root@LP11-D7891:~/eks-ingress# cat deployment-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app3-nginx-deployment
  labels:
    app: app3-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app3-nginx
  template:
    metadata:
      labels:
        app: app3-nginx
    spec:
      containers:
        - name: app3-nginx
          image: stacksimplify/kubenginx:1.0.0
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app3-nginx-nodeport-service
  labels:
    app: app3-nginx
  annotations:
#Important Note:  Need to add health check path annotations in service level if we are planning to use multiple targets in a load balancer
#    alb.ingress.kubernetes.io/healthcheck-path: /index.html
spec:
  type: NodePort
  selector:
    app: app3-nginx
  ports:
    - port: 80
      targetPort: 80
```

Ingress
```yaml
root@LP11-D7891:~/eks-ingress# cat ingress-alb.yaml
# Annotations Reference: https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-basics
  labels:
    app: app3-nginx
  annotations:
    # Load Balancer Name
    alb.ingress.kubernetes.io/load-balancer-name: ingress-basics
    #kubernetes.io/ingress.class: "alb" (OLD INGRESS CLASS NOTATION - STILL WORKS BUT RECOMMENDED TO USE IngressClass Resource) # Additional Notes: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/guide/ingress/ingress_class/#deprecated-kubernetesioingressclass-annotation
    # Ingress Core Settings
    alb.ingress.kubernetes.io/scheme: internet-facing
    # Health Check Settings
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/healthcheck-path: /index.html
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/success-codes: '200'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
spec:
  ingressClassName: aws-ingress-class # Ingress Class
  defaultBackend:
    service:
      name: app3-nginx-nodeport-service
      port:
        number: 80


# 1. If  "spec.ingressClassName: my-aws-ingress-class" not specified, will reference default ingress class on this kubernetes cluster
# 2. Default Ingress class is nothing but for which ingress class we have the annotation `ingressclass.kubernetes.io/is-default-class: "true"`
```