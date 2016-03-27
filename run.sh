#!/bin/sh

# TODO: check if user has `terraform`, `awscli`, and `jq` dependencies

# actually run terraform
terraform apply

# grab output from terraform on desired capacity, adding 1 for load balancer instance
desiredWebServerCount=`terraform output desired_web_server_count`
totalDesiredCapacity=$(($desiredWebServerCount+1))

# grab pem file path from `terraform.tfvars`
pathToPEM=$(cat terraform.tfvars | \
  grep "aws_pem_key_file_path.*\"" | \
  sed 's;\(aws_pem_key_file_path.*"\)\(.*\)\("\);\2;')

awscliInstances="awscli_instances.json"
tfInstances="terraform.tfstate"

getWebIPsAndCommandsForHAProxyConfig() {
  count=0
  while [ $count -lt $desiredWebServerCount ]; do
      numToASCII=$(($count + 66))
      serverName=$(printf \\$(printf '%03o' $numToASCII))
      jqStatement=`echo ".modules[].resources.\"aws_instance.web.$count\".primary.attributes.public_ip"`
      webServerPublicIP=$(cat "$tfInstances" | \
        jq -r "$jqStatement")
      echo "$@ \"echo '    server $serverName $webServerPublicIP:80 check' | sudo tee --append /etc/haproxy/haproxy.cfg\" && \\"
      let count=count+1
  done
  echo "$@ \"sudo systemctl restart haproxy.service\""
}

# make sure all instances are really up (e.g. when terraform isn't handling all the setup)
for retry in {1..7}; do

  # need to wait if desired amount of instances aren't ready yet
  secondsToSleep=$(($retry*$retry))

  # use awscli tool to query AWS's API and get info on instances
  aws ec2 describe-instances > "$awscliInstances"

  # check if desired capacity has been reached, if not, break and sleep
  cat "$awscliInstances" | \
  jq '.Reservations[].Instances[] | "\(.State.Name)"' | \
  sort | \
  uniq -c | \
  grep -q "   $totalDesiredCapacity \"running\"" \
    && \
    # can now assume that all instances are up, so extract info from `terraform.tfstate`, which is just a JSON file
    haproxyPublicIP=$(cat "$tfInstances" | \
      jq -r '.modules[].resources."aws_instance.haproxy_load_balancer".primary.attributes.public_ip') \
    && \
    # set things up to automatically output commands necessary to make manual part a bit less annoying
    sshLogin=`echo "ssh -t -o StrictHostKeyChecking=no -i $pathToPEM -A centos@$haproxyPublicIP"` \
    && \
    getWebIPsAndCommandsForHAProxyConfig "$sshLogin"  \
    && \
  # if desired capacity has not been reached, wait
  break || \
  sleep $secondsToSleep

done

rm "$awscliInstances"
