$ terraform -chdir="infra\terraform\aws\envs\dev" init -input=false -backend-config="bucket=dev-aks-bucket-backend" -backend-config="region=us-east-2"
$ terraform -chdir="infra\terraform\aws\envs\dev" plan 

Instance types
$ aws ec2 describe-instance-types --region us-east-2 --filters "Name=free-tier-eligible,Values=true" "Name=processor-info.supported-architecture,Values=x86_64" --query "InstanceTypes[].InstanceType" --output table