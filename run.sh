#!/bin/sh

# actually run terraform
terraform apply

# grab output from terraform on desired capacity, adding 1 for load balancer instance
desiredCapacity=$((`terraform output desired_web_server_count`+1))

awsInstances="_logs/instances.json"

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
  # if desired capacity has not been reached, wait
  break || \
  sleep $secondsToSleep

done
