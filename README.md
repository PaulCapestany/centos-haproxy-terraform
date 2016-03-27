# centos-haproxy-terraform

## Simple load-balanced web server deployment with Terraform

This repo is meant to be an example of how to easily set up an arbitrary-sized cluster of [CentOS 7](https://centos.org/) machines running [Apache HTTP servers](http://apache.org/) with web traffic load-balanced by [HAProxy](http://www.haproxy.org/) on AWS, automated with some shell scripting and [Terraform](https://terraform.io/). It's purposefully not using containers, service discovery, auto-scaling, etc, so no bleeding-edge DevOps here (though if you're interested in that, feel free to check out my [couchbase-sync-gateway-terraform](https://github.com/PaulCapestany/couchbase-sync-gateway-terraform) repo).

## Usage

* TODO: explain personal/secret info needed for setup
* TODO: explain `terraform`, `awscli`, and `jq` prerequisites
* TODO: explain what `run.sh` does
* TODO: explain load-balanced endpoints, and /stats
* TODO: explain SSHing into haproxy instance in order to manually run the following:

```
echo '    server B 54.165.16.45:80 check' | sudo tee --append /etc/haproxy/haproxy.cfg
echo '    server C 52.91.45.137:80 check' | sudo tee --append /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy.service
```
