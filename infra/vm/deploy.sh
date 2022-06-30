az group create --name pki --location westeurope
az deployment group create -g pki --template-file step-ca.bicep --parameters parameters.json