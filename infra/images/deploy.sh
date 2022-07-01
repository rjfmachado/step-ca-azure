az group create --name gallery --location westeurope
az deployment group create -g gallery --template-file deploy.bicep --parameters parameters.json