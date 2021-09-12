#!/bin/bash

RESOURCE_GROUP_NAME=devops-terraform
STORAGE_ACCOUNT_NAME=terraform20210911

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location eastus

# Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

# Create blob container
az storage container create --name shared-tfstate --account-name $STORAGE_ACCOUNT_NAME
az storage container create --name aks-tfstate --account-name $STORAGE_ACCOUNT_NAME