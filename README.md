
# Create Storage Account
`./create-storage.sh`


# SHARED

# terraform init local backend config
`terraform init -backend-config=azure.conf`

# terraform plan
`terraform plan`

# terraform apply
`terraform apply -auto-approve`

# terraform destroy
`terraform destroy -auto-approve`


# MAIN

# terraform init local backend config
`terraform init -backend-config=azure.conf`

# workspace
`terraform workspace new devqas`

# terraform plan
`terraform plan`

# terraform apply
`terraform apply -auto-approve`

# terraform destroy
`terraform destroy -auto-approve`