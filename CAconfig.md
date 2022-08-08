1. Bootstrap with DB and Key Vault
https://smallstep.com/docs/step-ca/installation


export AZURE_CLIENT_ID=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -H Metadata:true -s | jq -r .client_id)

1.
wget https://dl.step.sm/gh-release/cli/docs-ca-install/v0.21.0/step-cli_0.21.0_amd64.deb
sudo dpkg -i step-cli_0.21.0_amd64.deb

wget https://dl.step.sm/gh-release/certificates/docs-ca-install/v0.21.0/step-ca_0.21.0_amd64.deb
sudo dpkg -i step-ca_0.21.0_amd64.deb



https://smallstep.com/docs/step-cli/reference/ca/init


step ca init --deployment-type=standalone --name=TestPKI --dns ca.testpki.com --address=:443 --provisioner=ricardo.machado@microsoft.com --kms=azurekms

azurekms:name=my-root-key;vault=ricardmakvpki1

2. Remote Provisioners
https://smallstep.com/docs/step-ca/provisioners#remote-provisioner-management