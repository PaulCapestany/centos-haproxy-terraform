# centos-haproxy-terraform

## Simple load-balanced web server deployment with Terraform

This repo is meant to be an example of how to easily set up an arbitrary-sized cluster of [CentOS 7](https://centos.org/) machines running [Apache HTTP servers](http://apache.org/) with web traffic load-balanced by [HAProxy](http://www.haproxy.org/) on AWS, automated with some shell scripting and [Terraform](https://terraform.io/). It's purposefully not using containers, service discovery, auto-scaling, etc, so no bleeding-edge DevOps here (though if you're interested in that, feel free to check out my [couchbase-sync-gateway-terraform](https://github.com/PaulCapestany/couchbase-sync-gateway-terraform) repo).

## Usage

* TODO: explain personal/secret info needed for setup
* TODO: explain `terraform`, `awscli`, and `jq` prerequisites
* TODO: explain what `run.sh` does
* TODO: explain load-balanced endpoints [http://52.205.253.54/helloz](http://52.205.253.54/helloz), and [http://52.205.253.54/stats](http://52.205.253.54/stats)
* TODO: bring up default 20 t2.micro instance limit (and 10-node batching behavior)
* TODO: bring up apparent necessity for 7 minute sleep time to make sure all instances are up
* TODO: explain how one would SSH into one of the instances
* TODO: explain what the purpose of the auto-generated SSH commands are (and that they can be directly copy-pasted to run):
```
ssh -t -o StrictHostKeyChecking=no -i /Users/you/.ssh/aws/va_aws.pem -A centos@52.205.253.54 "echo '    server B 54.84.200.0:80 check' | sudo tee --append /etc/haproxy/haproxy.cfg" && \
ssh -t -o StrictHostKeyChecking=no -i /Users/you/.ssh/aws/va_aws.pem -A centos@52.205.253.54 "echo '    server C 54.164.107.250:80 check' | sudo tee --append /etc/haproxy/haproxy.cfg" && \
ssh -t -o StrictHostKeyChecking=no -i /Users/you/.ssh/aws/va_aws.pem -A centos@52.205.253.54 "echo '    server D 52.90.105.171:80 check' | sudo tee --append /etc/haproxy/haproxy.cfg" && \
ssh -t -o StrictHostKeyChecking=no -i /Users/you/.ssh/aws/va_aws.pem -A centos@52.205.253.54 "echo '    server E 52.207.248.245:80 check' | sudo tee --append /etc/haproxy/haproxy.cfg" && \
ssh -t -o StrictHostKeyChecking=no -i /Users/you/.ssh/aws/va_aws.pem -A centos@52.205.253.54 "sudo systemctl restart haproxy.service"
```

* TODO: explain how to destroy cluster
