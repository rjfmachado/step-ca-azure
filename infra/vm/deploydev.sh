az group create --name pkidev --location westeurope
az deployment group create -g pkidev --template-file step-ca.bicep --parameters dev.json caVMsshKey=@./ssh/mini.pub