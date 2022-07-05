az group create --name pkiprod --location westeurope
az deployment group create -g pkiprod --template-file step-ca.bicep --parameters prod.json