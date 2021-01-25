#! /bin/bash

keyName="schafke"
instanceType="t3.xlarge"
# instanceType="t2.micro"
# amiId="ami-0cac0a7e7f05274f6" # ubuntu bionic
amiId="ami-02444602b067fd967" # ubuntu bionic with packages and boringssl built
securityGroup="sg-082bee86921c47240"
# Add these back in to change disk size
# diskSize="250"
# --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$diskSize,\"DeleteOnTermination\":true}}]" \

output=$(aws ec2 run-instances \
    --image-id $amiId \
    --count 1 \
    --instance-type $instanceType \
    --key-name $keyName \
    --security-group-ids $securityGroup \
    2>&1)

retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error starting EC2 instance: $output"
    exit 1
fi

instanceId=$(echo $output | jq -r .Instances[].InstanceId)

echo "Launched instance $instanceId"

aws ec2 create-tags --resources $instanceId --tags "Key=Name,Value=Go Build Svr"
echo "Tagged instance $instanceId as Go Build Svr"

while [ "$stateName" != "running" ]
do
    stateName=$(aws ec2 describe-instances --instance-ids $instanceId | jq -r .Reservations[].Instances[].State.Name)
    echo "Instance is $stateName"
    if [ "$stateName" != "running" ]; then
        sleep 4
    fi
done

publicIp=$(aws ec2 describe-instances --instance-ids $instanceId | jq -r .Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp)
echo "Instance ready with public IP $publicIp"

while [ "$sshOk" != "0" ]
do
    echo "Attempting connection to $publicIp"
    ssh -o ConnectTimeout=2 -oStrictHostKeyChecking=no ubuntu@${publicIp} "exit"
    sshOk=$?
    if [ "$sshOk" != "0" ]; then
        echo "Connection timed out"
        sleep 8
    else
        echo "Connection ready"
    fi
done

echo "Copying files"
scp ./build_remote.sh ubuntu@${publicIp}:
scp ~/.ssh/id_rsa* ubuntu@${publicIp}:

ssh ubuntu@${publicIp} << EOF
    sudo mv ./build_remote.sh /root
    sudo mv id_rsa /root/.ssh/
    sudo mv id_rsa.pub /root/.ssh/
    sudo su -
    chown root: /root/.ssh/*
    echo "github.com,140.82.114.4 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> /root/.ssh/known_hosts
    exit
EOF

ssh ubuntu@${publicIp} "sudo /root/build_remote.sh"

goFile=$(cat ./build_remote.sh | grep "^export GOZIP.*$" | awk -F = '{print $2}')

ssh ubuntu@${publicIp} << EOF
    sudo mv /root/${goFile} /home/ubuntu
    sudo chown ubuntu: /home/ubuntu/${goFile}
    exit
EOF

scp ubuntu@${publicIp}:/home/ubuntu/${goFile} .

csum=$(shasum -a 256 ./${goFile} | awk '{print $1}')

echo "Built Go ${goFile} with cksum ${csum}"

aws ec2 terminate-instances --instance-ids $instanceId