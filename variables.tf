# "nano" AWS instances seem too slow/buggy for this demo, use "micro" or above
variable "instance_type" {
  default = "t2.micro"
}

# the CentOS AMI should be HVM: https://wiki.centos.org/Cloud/AWS
# (make sure the AMI is for the proper aws region)
variable "aws_centos_ami" {
  default = "ami-6d1c2007"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "desired_web_server_count" {
  default = 20
}

########################
# PERSONAL/SECRET VARS #
########################

# personal variables, should only be entered in `terraform.tfvars` file
variable "aws_pem_key_file_path" {}
variable "aws_key_name" {}

# secret variables, should also only be entered in `terraform.tfvars` file
variable "aws_access_key" {}
variable "aws_secret_key" {}
