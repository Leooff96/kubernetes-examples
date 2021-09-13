#!/bin/bash

NETWORK_INTERFACE_ID=$(az network private-endpoint show --name $ENDPOINT_NAME --resource-group $RG_NAME --query 'networkInterfaces[0].id' --output tsv)
PRIVATE_IP=$(az resource show --ids $NETWORK_INTERFACE_ID --api-version 2019-04-01 --query 'properties.ipConfigurations[1].properties.privateIPAddress' --output tsv)
DATA_ENDPOINT_PRIVATE_IP=$(az resource show --ids $NETWORK_INTERFACE_ID --api-version 2019-04-01 --query 'properties.ipConfigurations[0].properties.privateIPAddress' --output tsv)
az network private-dns record-set a create --name $AZUREACR_NAME --zone-name privatelink.azurecr.io --resource-group $RG_NAME
az network private-dns record-set a create --name $AZUREACR_NAME.eastus2.data --zone-name privatelink.azurecr.io --resource-group $RG_NAME
az network private-dns record-set a add-record --record-set-name $AZUREACR_NAME --zone-name privatelink.azurecr.io --resource-group $RG_NAME --ipv4-address $PRIVATE_IP
az network private-dns record-set a add-record --record-set-name $AZUREACR_NAME.eastus2.data --zone-name privatelink.azurecr.io --resource-group $RG_NAME --ipv4-address $DATA_ENDPOINT_PRIVATE_IP