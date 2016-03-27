#!/bin/sh

# TODO: check if user has `terraform`, `awscli`, and `jq` dependencies

# actually run terraform
terraform apply

# grab output from terraform on desired capacity, adding 1 for load balancer instance
desiredWebInstanceCount=`terraform output desired_web_server_count`
totalDesiredCapacity=$(($desiredWebInstanceCount+1))

# grab pem file path from `terraform.tfvars`
pathToPEM=$(cat terraform.tfvars | \
  grep "aws_pem_key_file_path.*\"" | \
  sed 's;\(aws_pem_key_file_path.*"\)\(.*\)\("\);\2;')

awscliInstances="awscli_instances.json"
tfInstances="terraform.tfstate"

generateAndRunCommandsForHAProxyConfig() {
  # put all generated ssh commands into temp file to then run
  echo "#!/bin/sh" > tmpSSHCommandsFile
  chmod +x tmpSSHCommandsFile
  webInstanceCount=0
  errorCount=0
  successString=""
  errorString=""
  while [ $webInstanceCount -lt $desiredWebInstanceCount ]; do
      numToASCII=$(($webInstanceCount + 66))
      serverName=$(printf \\$(printf '%03o' $numToASCII))
      jqStatement=`echo ".modules[].resources.\"aws_instance.web.$webInstanceCount\".primary.attributes.public_ip"`
      webServerPublicIP=$(cat "$tfInstances" | \
        jq -r "$jqStatement")
      if [[ $webServerPublicIP == *"null"* ]]; then
        errorString="${errorString}ERROR: Instance \"$serverName\" at $webServerPublicIP failed to launch properly, so it was not added to HAProxy config.\n"
        errorCount=$((errorCount+1))
      else
        echo "$@ \"echo '    server $serverName $webServerPublicIP:80 check' | sudo tee --append /etc/haproxy/haproxy.cfg\"" >> tmpSSHCommandsFile
        successString="${successString}Instance \"$serverName\" is at http://$webServerPublicIP/helloz\n"
      fi
      webInstanceCount=$((webInstanceCount+1))
  done
  echo "$@ \"sudo systemctl restart haproxy.service\"" >> tmpSSHCommandsFile
  # finally, run the full shell script, and delete tmpSSHCommandsFile
  ./tmpSSHCommandsFile
  rm tmpSSHCommandsFile
  if [ $errorCount -eq 0 ]; then
    echo "\nSUCCESS: Deploy went flawlessly!\n\nHere's how you can find everything:\n\n$successString"
  else
    echo "\nFinished, but with errors. The following were deployed successfully:\n"
    echo "$successString\n"
    echo "You may want to look at the \"Instances\" section of https://console.aws.amazon.com/ec2/v2/home to see what went wrong with the following:\n"
    echo "$errorString"
  fi
}

# make sure all instances are really up (e.g. if terraform wasn't handling a lot of the setup already)
for retry in {1..7}; do
  # need to wait if desired amount of instances aren't ready yet
  secondsToSleep=$(($retry*$retry))

  # use awscli tool to query AWS's API and get info on instances
  aws ec2 describe-instances > "$awscliInstances"

  # check if desired capacity has been reached, if so, break. If not, sleep and retry
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
    # set things up to generate necessary ssh commands for load-balancer config
    sshLogin=`echo "ssh -t -o StrictHostKeyChecking=no -i $pathToPEM -A centos@$haproxyPublicIP"` \
    && \
    # grab all of the web servers' public IPs and names and run ssh commands to finish haproxy setup
    generateAndRunCommandsForHAProxyConfig "$sshLogin"  \
    && \
    echo "Instance \"A\" (load-balancer) is live at: http://$haproxyPublicIP/helloz" \
    && \
    echo "HAProxy Stats can be found at: http://$haproxyPublicIP/stats" \
    && \
  break || \

  # if desired capacity has not been reached, wait
  sleep $secondsToSleep
done

rm "$awscliInstances"
