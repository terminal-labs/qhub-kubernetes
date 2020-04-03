provider "kubernetes" {
  load_config_file       = false
  host                   = module.kubernetes.credentials.endpoint
  token                  = module.kubernetes.credentials.token
  cluster_ca_certificate = module.kubernetes.credentials.cluster_ca_certificate
}

module "kubernetes-initialization" {
  source = "../../quansight-terraform-modules/modules/kubernetes/initialization"

  namespace = var.environment
  secrets   = []
}


{% if cookiecutter.provider == "aws" -%}
module "kubernetes-nfs-mount" {
  source = "../../quansight-terraform-modules/modules/kubernetes/nfs-mount"

  name         = "nfs-mount"
  namespace    = var.environment
  nfs_capacity = "10Gi"
  nfs_endpoint = module.efs.credentials.dns_name
}
{% else -%}
module "kubernetes-nfs-server" {
  source = "../../quansight-terraform-modules/modules/kubernetes/nfs-server"

  name         = "nfs-server"
  namespace    = var.environment
  nfs_capacity = "10Gi"
}

module "kubernetes-nfs-mount" {
  source = "../../quansight-terraform-modules/modules/kubernetes/nfs-mount"

  name         = "nfs-mount"
  namespace    = var.environment
  nfs_capacity = "10Gi"
  nfs_endpoint = module.kubernetes-nfs-server.endpoint_ip
}
{% endif %}

provider "helm" {
  kubernetes {
    load_config_file       = false
    host                   = module.kubernetes.credentials.endpoint
    token                  = module.kubernetes.credentials.token
    cluster_ca_certificate = module.kubernetes.credentials.cluster_ca_certificate
  }
  version = "1.0.0"
}

{% if cookiecutter.provider == "aws" -%}
module "kubernetes-autoscaling" {
  source = "../../quansight-terraform-modules/modules/kubernetes/services/cluster-autoscaler"

  namespace = var.environment

  aws-region   = var.region
  cluster-name = local.cluster_name
}
{% endif -%}

module "kubernetes-ingress" {
  source = "../../quansight-terraform-modules/modules/kubernetes/ingress"

  namespace = var.environment

  node-group = local.node_groups.general
}

module "qhub" {
  source = "../../quansight-terraform-modules/modules/kubernetes/services/meta/qhub"

  name      = "qhub"
  namespace = var.environment

  home-pvc = module.kubernetes-nfs-mount.persistent_volume_claim.name

  external-url = var.endpoint

  user-image = {
    name = var.image.name
    tag  = var.image.tag
  }

  general-node-group = local.node_groups.general
  user-node-group    = local.node_groups.user
  worker-node-group  = local.node_groups.worker

  jupyterhub-overrides = [
    file("jupyterhub.yaml")
  ]
}