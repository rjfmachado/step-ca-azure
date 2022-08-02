export AZURE_RG_NAME='pki'
export AZURE_LOCATION='westeurope'
export AAD_DEPLOY_APP_NAME='pkideploy'
export SSH_PUBLIC_KEY_PATH='~/.ssh/id_rsa.pub'

ssh-keygen 
//if they container got rebuilt - this breaks the deployment... need a more permanent solution..


az group create --name $AZURE_RG_NAME --location $AZURE_LOCATION -o none
az deployment group create -g $AZURE_RG_NAME --template-file infra/base/step-ca-infra.bicep --parameters infra/base/defaults.json --parameters caVMsshKey=@$SSH_PUBLIC_KEY_PATH -o none


#in the CA
#the mi client ID
export AZURE_CLIENT_ID=d2b056c4-c917-492a-84e9-75ce5a1c4a46

wget https://dl.step.sm/gh-release/cli/docs-ca-install/v0.21.0/step-cli_0.21.0_amd64.deb
sudo dpkg -i step-cli_0.21.0_amd64.deb

tep ca init --kms azurekms
✔ Deployment Type: Standalone
What would you like to name your new PKI?
✔ (e.g. Smallstep): testpki
What URI would you like to use for the root certificate key?
✔ (e.g. azurekms:name=my-root-key;vault=my-vault): azurekms:name=my-root-key;vault=ricardmakvpki1
What URI would you like to use for the intermediate certificate key?
✔ (e.g. azurekms:name=my-intermediate-key;vault=my-vault): azurekms:name=int-key;vault=ricardmakvpki1
What DNS names or IP addresses would you like to add to your new CA?
✔ (e.g. ca.smallstep.com[,1.1.1.1,etc.]): testlocal.com
What IP and port will your new CA bind to?
✔ (e.g. :443 or 127.0.0.1:443): :443
What would you like to name the CA's first provisioner?
✔ (e.g. you@smallstep.com): ricardma@microsoft.com█
Choose a password for your first provisioner.
✔ [leave empty and we'll generate one]: 
✔ Password: K9'%(R==K-)YLf,.=Lo7-p46&Yhtdw{*

Generating root certificate... done!
Generating intermediate certificate... done!

✔ Root certificate: /home/stepcaadmin/.step/certs/root_ca.crt
✔ Root private key: azurekms:name=my-root-key;vault=ricardmakvpki1?version=791f4c452fe84d7fab467e348f769e8c
✔ Root fingerprint: 34e640f6dd35bb6bc2fc0457de120a522ee1861aaa73bbe9620c98dfa18ae721
✔ Intermediate certificate: /home/stepcaadmin/.step/certs/intermediate_ca.crt
✔ Intermediate private key: azurekms:name=int-key;vault=ricardmakvpki1?version=dc8350540088475894911962f4d20ceb
✔ Database folder: /home/stepcaadmin/.step/db
✔ Default configuration: /home/stepcaadmin/.step/config/defaults.json
✔ Certificate Authority configuration: /home/stepcaadmin/.step/config/ca.json

Your PKI is ready to go. To generate certificates for individual services see 'step help ca'.

FEEDBACK 😍 🍻
  The step utility is not instrumented for usage statistics. It does not phone
  home. But your feedback is extremely valuable. Any information you can provide
  regarding how you’re using `step` helps. Please send us a sentence or two,
  good or bad at feedback@smallstep.com or join GitHub Discussions
  https://github.com/smallstep/certificates/discussions and our Discord 
  https://u.step.sm/discord.