az group create --name pki --location westeurope
az deployment group create -g pki --template-file ./infra/vm/step-ca.bicep