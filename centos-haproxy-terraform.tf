# the access_key and secret_key get read from the `terraform.tfvars` file
# `terraform.tfvars` is the only file that should *NOT* be committed!
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

resource "aws_security_group" "terraform_example_security_group" {
    name = "terraform_example_sg"
    description = "Created via Terraform"

    ########################
    # AWS ALLOW ALL EGRESS #
    ########################

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ##################
    # STANDARD PORTS #
    ##################

    # SSH access (should theoretically be a whitelist, not potentially open to any IP...)
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTP access from anywhere
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "haproxy_load_balancer" {
    security_groups = ["${aws_security_group.terraform_example_security_group.name}"]

    instance_type = "${var.instance_type}"

    ami = "${var.aws_centos_ami}"

    # The connection block tells our provisioner how to
    # communicate with the resource (instance)
    connection {
        user = "centos"
        key_file = "${var.aws_pem_key_file_path}"
    }

    key_name = "${var.aws_key_name}"

    count = 1

    provisioner "file" {
        source = "tf-remote-haproxy-script.sh"
        destination = "/tmp/tf-remote-haproxy-script.sh"
    }

    provisioner "remote-exec" {
        inline = [
          "chmod +x /tmp/tf-remote-haproxy-script.sh",
          "sudo /tmp/tf-remote-haproxy-script.sh"
        ]
    }
}

resource "aws_instance" "web" {
    security_groups = ["${aws_security_group.terraform_example_security_group.name}"]

    instance_type = "${var.instance_type}"

    ami = "${var.aws_centos_ami}"

    connection {
        user = "centos"
        key_file = "${var.aws_pem_key_file_path}"
    }

    key_name = "${var.aws_key_name}"

    count = "${var.desired_web_server_count}"

    provisioner "file" {
        source = "tf-remote-web-script.sh"
        destination = "/tmp/tf-remote-web-script.sh"
    }

    provisioner "remote-exec" {
        inline = [
          "chmod +x /tmp/tf-remote-web-script.sh",
          "sudo /tmp/tf-remote-web-script.sh ${count.index}"
        ]
    }
}

output "desired_web_server_count" {
    value = "${var.desired_web_server_count}"
}
