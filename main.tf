module "stnf-vpc" {
  source = "./modules/vpc"

  region               = "us-east-1"
  vpc_cidr             = "192.168.0.0/24"
  name                 = "stanf-vpc"
  env                  = "dev"
  public_subnets_cidr  = ["192.168.0.0/26", "192.168.0.64/26"]
  private_subnets_cidr = ["192.168.0.128/26", "192.168.0.192/26"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
}
module "stnf-ecr" {
  source = "./modules/nonfunctional"

  image_mutable = "IMMUTABLE"
  encrypt_type  = "KMS"
  ecr_name      = "stnf-images"
  env           = "dev"
  region        = "us-east-1"
  
}

