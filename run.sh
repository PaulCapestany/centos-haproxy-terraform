#!/bin/sh

# TODO: check if user has `terraform`, `awscli`, and `jq` dependencies

# actually run terraform
terraform apply

# grab output from terraform on desired capacity, adding 1 for load balancer instance
desiredCapacity=$((`terraform output desired_web_server_count`+1))

# TODO: should clean this up
awsInstances="_logs/instances.json"

# grab pem file path from `terraform.tfvars`
pathToPEM=$(cat terraform.tfvars | \
  grep "aws_pem_key_file_path.*\"" | \
  sed 's;\(aws_pem_key_file_path.*"\)\(.*\)\("\);\2;')

# make sure all instances are up in order to get useful info, like public/private IPs
for count in {1..7}; do

  # need to wait if desired amount of instances aren't ready yet
  secondsToSleep=$(($count*$count))

  # use awscli tool to query AWS's API and get info on instances
  aws ec2 describe-instances > "$awsInstances"

  # check if desired capacity has been reached, if not, break and sleep
  cat "$awsInstances" | \
  jq '.Reservations[].Instances[] | "\(.State.Name)"' | \
  sort | \
  uniq -c | \
  grep -q "   $desiredCapacity \"running\"" \
    && \
    # extract both public and private IP addresses for easy access in info.html
    cat "$awsInstances" | \
      jq -r '.Reservations[].Instances[] | "<p>Public Endpoint: <a href=\"http://\(.PublicIpAddress)/helloz\">http://\(.PublicIpAddress)/helloz</a></p><p>Private IP: \(.PrivateIpAddress)</p><br>"' | \
      sort | \
      sed 's;.*http://null.*;;' | \
      sed '/./!d' > info.html \
    && \
    # automatically output commands necessary to make manual part a bit less annoying
    cat "$awsInstances" | \
      # ssh commands for each machine
      jq -r --arg JQ_ARG "$pathToPEM" '.Reservations[].Instances[] | "ssh -o StrictHostKeyChecking=no -i \($JQ_ARG) -A centos@\(.PublicIpAddress)"' | \
      sort | \
      uniq | \
      sed '/.*@null$/d' \
    && \
    echo "--------------------------------------------------------------------" \
    && \
    cat "$awsInstances" | \
      # command to run on haproxy instance to setup load-balancing
      jq -r '.Reservations[].Instances[] | "\(.PublicIpAddress)"' | \
      sort | \
      sed 's;.*null.*;;' | \
      sed '/./!d' | \
      sed "s;\(.*\);echo \'    server INSERT_INSTANCE_NAME_HERE \1:80 check\' | sudo tee --append /etc/haproxy/haproxy.cfg \&\& \\\;" \
      && \
      echo "sudo systemctl restart haproxy.service" \
    && \
  # if desired capacity has not been reached, wait
  break || \
  sleep $secondsToSleep

done
