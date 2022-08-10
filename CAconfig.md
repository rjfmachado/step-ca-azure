# Configuring your CA

Consider this guidance the minimum set of steps required to stand up step-ca in a VM in Azure, using Key Vault and MySQL Backend.
Please refer to smallstep documentation and guidance for any configuration changes or guidance. For convenience, I'm adding here the documentation referenced by me while building this sample.

1. Bootstrap with DB and Key Vault
https://smallstep.com/docs/step-ca/installation
https://smallstep.com/docs/step-ca/configuration
https://smallstep.com/docs/step-ca/configuration/#azure-key-vault

```bash
wget https://dl.step.sm/gh-release/cli/docs-ca-install/v0.21.0/step-cli_0.21.0_amd64.deb
sudo dpkg -i step-cli_0.21.0_amd64.deb

wget https://dl.step.sm/gh-release/certificates/docs-ca-install/v0.21.0/step-ca_0.21.0_amd64.deb
sudo dpkg -i step-ca_0.21.0_amd64.deb
```

1. Run step ca as a daemon

1. Running step ca in production
https://smallstep.com/docs/step-ca/certificate-authority-server-production


export AZURE_CLIENT_ID=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -H Metadata:true -s | jq -r .client_id)



https://smallstep.com/docs/step-cli/reference/ca/init

step ca init --deployment-type=standalone --name=TestPKI --dns ca.testpki.com --address=:443 --provisioner=ricardo.machado@microsoft.com --kms=azurekms --no-db

step ca init --deployment-type=standalone --name=TestPKI --dns ca.testpki.com --address=:443 --provisioner=ricardo.<machado@microsoft.com --kms=azurekms --no-db

azurekms:name=rootkey;vault=ricardmakvpki1
azurekms:name=intermediatekey;vault=ricardmakvpki1


1. setup the daemon
https://smallstep.com/docs/step-ca/certificate-authority-server-production#running-step-ca-as-a-daemon
https://gist.github.com/circa10a/e6cfc673af9282d17dfb958ef6adabeb
//this one to set the clientid env var for the service, also check the file based auth mentioned in the install guidance.

insert Environment=AZURE_CLIENT_ID=09e89594-0607-40b4-8b91-6de23544489d in 
/etc/systemd/system/step-ca.service

TODO:
database
https://github.com/smallstep/step-kms-plugin
https://raw.githubusercontent.com/smallstep/certificates/master/examples/pki/config/ca.json
https://smallstep.com/docs/step-ca/provisioners#remote-provisioner-management
