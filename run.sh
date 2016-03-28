#!/bin/sh

# Actually runs terraform
terraform apply

######################################################################
# The rest of this script configures everything not handled after    #
# `terraform apply`. Normally you might use tools like etcd/fleet to #
# handle automating service discovery etc, but tried to keep things  #
# a bit more straightforward for the purposes of this demo           #
######################################################################

# Grab output from terraform on desired capacity, adding 1 for load balancer instance
desiredWebInstanceCount=`terraform output desired_web_server_count`
totalDesiredCapacity=$(($desiredWebInstanceCount+1))

# Grab pem file path from `terraform.tfvars`
pathToPEM=$(cat terraform.tfvars | \
  grep "aws_pem_key_file_path.*\"" | \
  sed 's;\(aws_pem_key_file_path.*"\)\(.*\)\("\);\2;')

# tmp file used to keep a query via `awscli` tool of the state of instances before terraform has fully executed
awscliInstances="awscli_instances.json"

# This file is the "source of truth" for the state of instances/infrastructure once terraform is done running
tfInstances="terraform.tfstate"

# This is sort of a poor man's version of "service discovery", automates grabbing the
# IPs of all the deployed web servers and then adds to HAProxy config
generateAndRunCommandsForHAProxyConfig() {
  # put all generated ssh commands into temp file to then run
  echo "#!/bin/sh" > tmpSSHCommandsFile
  chmod +x tmpSSHCommandsFile
  webInstanceCount=0
  errorCount=0
  successString=""
  errorString=""
  while [ $webInstanceCount -lt $desiredWebInstanceCount ]; do
      # Convert "count.index" argument provided in .tf file to ASCII letter
      # Note: add 66 so that arg of 0 maps to B, 1 to C, etc...
      numToASCII=$(($webInstanceCount + 66))
      serverName=$(printf \\$(printf '%03o' $numToASCII))
      # Use `jq` to extract useful JSON contained in terraform.tfstate file, i.e. public IPs
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
  # Finally, run the full shell script we created to config HAProxy, and then delete tmpSSHCommandsFile
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

# Use exponential backoff to check if all instances are really up (e.g. if terraform wasn't handling a lot of the setup already)
# This really isn't necessary in this specific demo, but kept it in just in case real service discovery/etc were to be used
for retry in {1..7}; do
  # Need to wait if desired amount of instances aren't ready yet
  secondsToSleep=$(($retry*$retry))

  # Use awscli tool to query AWS's API and get info on instances
  aws ec2 describe-instances > "$awscliInstances"

  # Check if desired capacity has been reached, if so, break. If not, sleep and retry
  cat "$awscliInstances" | \
  jq '.Reservations[].Instances[] | "\(.State.Name)"' | \
  sort | \
  uniq -c | \
  grep -q "   $totalDesiredCapacity \"running\"" \
    && \
    # Can now assume that all instances are up, so extract info from `terraform.tfstate`, which is just a JSON file
    haproxyPublicIP=$(cat "$tfInstances" | \
      jq -r '.modules[].resources."aws_instance.haproxy_load_balancer".primary.attributes.public_ip') \
    && \
    # Set things up to generate necessary ssh commands for load-balancer config
    sshLogin=`echo "ssh -t -o StrictHostKeyChecking=no -i $pathToPEM -A centos@$haproxyPublicIP"` \
    && \
    # Grab all of the web servers' public IPs and names and run ssh commands to finish haproxy setup
    generateAndRunCommandsForHAProxyConfig "$sshLogin"  \
    && \
    echo "Instance \"A\" (load-balancer) is live at: http://$haproxyPublicIP/helloz" \
    && \
    echo "HAProxy Stats can be found at: http://$haproxyPublicIP/stats" \
    && \
  break || \

  # If desired capacity has not been reached, wait
  sleep $secondsToSleep
done

rm "$awscliInstances"
