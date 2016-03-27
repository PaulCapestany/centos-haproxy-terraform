# Load-balanced server deployment with Terraform

This repo is meant to be an example of how to easily set up an arbitrary-sized cluster of [CentOS 7](https://centos.org/) machines running [Apache HTTP servers](http://apache.org/) with web traffic load-balanced by [HAProxy](http://www.haproxy.org/) on AWS, automated with some shell scripting and [Terraform](https://terraform.io/). It's purposefully not using containers, service discovery, auto-scaling, etc, so no bleeding-edge DevOps\* here.

### Demo explanation

By default, this demo sets up ***one*** *t2.micro* AWS instance running HAProxy, which we'll call instance **"A"**. The point of **"A"** is to act as a load-balancer for the ***four*** *t2.micro* AWS instances that will be running httpd and responding to requests from the endpoint *[/helloz](http://52.23.181.242/helloz)* with their respective names of **"B"**, **"C"**, **"D"**, and **"E"**. Requests will roundrobin, so refreshing the **"A"** *[/helloz](http://52.23.181.242/helloz)* endpoint should show an equal distribution of responses by each individual web instance.

If any of the web instances are turned off they will return to serving traffic once online again (the load-balancer will also resume its job if rebooted). HAProxy's admin interface is exposed at *[/stats](http://52.23.181.242/stats)* for convenience and testing purposes.

\* if further automating SysAdmin-like tasks is of interest to you, feel free to check out my [couchbase-sync-gateway-terraform](https://github.com/PaulCapestany/couchbase-sync-gateway-terraform) repo.

## Usage

Once you're set up, launching entire clusters is as simple as typing `./run.sh`, no need for manual SSHing and configuration, and no need to waste time in the AWS dashboard either. Similarly, destroying an entire cluster is as easy as typing `terraform destroy -force`.

### Dependencies

First you need to make sure you have the following command line tools locally installed:

* [terraform](https://www.terraform.io/): infrastructure configuration and launch tool which is provider-agnostic
* [awscli](https://aws.amazon.com/cli/): Amazon's unified tool to manage AWS services
* [jq](https://stedolan.github.io/jq/): like `sed` for JSON

If you don't have them and are running OS X, running `brew install ____` will get any of them on your system.

### Setup

Clone this repo with `git clone https://github.com/PaulCapestany/centos-haproxy-terraform.git` and `cd` to the project. In it, you'll see the *terraform.tfvars-example* file, make a copy of it, naming it *terraform.tfvars* and put your personal info in it. You should make sure you never check this file into git/Github.

Next, take a look at the *variables.tf* file. You don't need to change any of them, but if you wanted to change the number of web servers that get deployed, that's where you'd do so. Part of the point of terraform is to keep infrastructure configuration changes under version control (for example, you'd want to make commits after any `terraform apply` or `terraform destroy` actions). It might help to read [Introduction to Terraform](https://www.terraform.io/intro/index.html) to learn more, but you shouldn't need to in order to run this demo.

Last but not least, execute your deployment with `./run.sh` and sit back and relax... you're done! The *run.sh* shell script basically just runs `terraform apply` for you, as well as some extra post-launch tasks, such as getting the IPs of the web servers to automatically add them to HAProxy's configuration file, and then restarting the service for you via `ssh`.

When everything is done launching (which in my testing can take up to 10 minutes), you should see something similar to this:

```
SUCCESS: Deploy went flawlessly!

Here's how you can find everything:

Instance "B" is at http://52.87.205.58/helloz
Instance "C" is at http://52.201.225.41/helloz
Instance "D" is at http://54.88.147.244/helloz
Instance "E" is at http://52.207.254.31/helloz

Instance "A" (load-balancer) is live at: http://52.23.181.242/helloz
HAProxy Stats can be found at: http://52.23.181.242/stats
```

Note that *[/stats](http://52.23.181.242/stats)* is ***[not secured](https://github.com/PaulCapestany/centos-haproxy-terraform/commit/8223d8b7c526816ca06e1a71020dd4716a1e8935#diff-b3a5e984b67ba5d8ad95fa03e148e54bR67)*** for the purposes of this demo, and allows anyone to easily take backends down/up/etc via the admin panel. You probably wouldn't want to do this otherwise, but it's a quick and straightforward way to test whether your HAProxy load-balancer is really working properly.

## Avoid unexpected AWS bills!!!

***IMPORTANT:*** to completely destroy the cluster, run `terraform destroy -force` within the project directory, otherwise you might get an unexpectedly more expensive AWS bill.
