variable "image_mutable" {
  type    = string
  default = "IMMUTABLE"
  
}
variable "encrypt_type" {
  type    = string
  default = "KMS"
}
variable "ecr_name" {
  type    = string
  default = "stnf-images"
  
}
variable "env" {
  type    = string
  default = "dev"
  
}
variable "region" {
  type    = string
  default = "us-east-1"
  
}