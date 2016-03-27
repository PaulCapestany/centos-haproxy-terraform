variable "desired_web_server_count" {
  default = 2
}
variable "aws_pem_key_file_path" {}
variable "aws_key_name" {}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
  default = "us-east-1"
}
variable "aws_centos_ami" {
  default = "ami-6d1c2007"
}
