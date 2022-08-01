export AZURE_RG_NAME='pki'
export AZURE_LOCATION='westeurope'
export AAD_DEPLOY_APP_NAME='pkideploy'
export SSH_PUBLIC_KEY_PATH='~/.ssh/id_rsa.pub'

ssh-keygen 
//if they container got rebuilt - this breaks the deployment... need a more permanent solution..


az group create --name $AZURE_RG_NAME --location $AZURE_LOCATION -o none
az deployment group create -g $AZURE_RG_NAME --template-file infra/base/step-ca-infra.bicep --parameters infra/base/defaults.json --parameters caVMsshKey=@$SSH_PUBLIC_KEY_PATH -o none