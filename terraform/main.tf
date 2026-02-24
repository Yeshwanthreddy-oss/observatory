# Root module: wires the network and platform building blocks together.

module "network" {
  source = "./modules/network"

  project      = var.project
  vpc_cidr     = var.vpc_cidr
  subnet_cidrs = var.subnet_cidrs
}

module "platform" {
  source = "./modules/platform"

  project            = var.project
  log_retention_days = var.log_retention_days

  # The Lambda runs inside the VPC's subnets, guarded by the shared SG.
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.subnet_ids
  security_group_ids = [module.network.security_group_id]
}
