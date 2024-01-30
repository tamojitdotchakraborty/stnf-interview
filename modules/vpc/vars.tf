variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type = string
}

variable "name" {
  type = string
}

variable "env" {
  type = string
}

variable "public_subnets_cidr" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "private_subnets_cidr" {
  type = list(string)
}
variable "instance_type" {
  type    = string
  default = "t2.micro"
}
  
variable "instance_name" {
  type    = string
  default = "mongodb-dev"
}
variable "ami_key_pair_name"  {  
  type    = string
  default = "ameren-dev-bastion"  
  
}  
variable "ami_id"  {  
  type    = string
  default = "ami-007855ac798b5175e"  
  
}
variable "mongodb_key_pair_path"  {  
  type    = string
  default = "/Users/tamojitchakraborty/.aws/ec2keys/ameren-dev-bastion.pem"  
  
}

variable "stnf-alb-sg"  {  
  type    = string
  default = "alb-sg"  
  
}
variable "stnf-container-http-port" {
  type    = string
  default = "80"
  
}
variable "stnf-container-https-port" {
  type    = string
  default = "443"
  
}
variable "stnf-ecs-roles-name" {
  type    = string
  default = "stnf-ecs-roles"
  
}

  

  

