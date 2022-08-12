# step-ca-azure

A sample implementation of step-ca on Azure leveraging Azure Key Vault, Azure MySQL and Managed Identities.

TODO: Add a picture and broader explanation.  
TODO: Move defaults.json into the template/ENV

> The below guidance has been designed and tested on the included GitHub codespaces environment.

## Deploying the solution

1. Login to your target subscription with Azure CLI and ensure it's the current default subscription.

    ```bash
    az login
    az account show -o tsv --query name
    ```

2. This guidance and provided github workflows expect the following environment variables to be present:

    | Variable   |      Default value    |  Notes |
    |-|-:|-:|
    | AZURE_RG_NAME | | Target Resource Group |
    | AZURE_LOCATION | westeurope | Target region for the deployment |
    | CA_CAVMNAME | | Virtual Machine name |
    | CA_KEYVAULTNAME | | Key Vault name - Must be unique |
    | CA_SSH_PUBLIC_KEY | | SSH Public Key |
    | DB_ADMIN_PASSWORD | | Database admin user password | 
    | CA_INIT_PASSWORD | | Parameter for step ca init --password-file contents |
    | CA_INIT_COMMAND | | CA Initialization instructions |


    Sample CA init for Azure Key Vault, please refer to [step ca init documentation](https://smallstep.com/docs/step-cli/reference/ca/init) for more information:

    ```bash
    export CA_INIT_COMMAND="step ca init --deployment-type=standalone --name=[CA_INIT_NAME] --dns=[CA_INIT_DNS] --address=[CA_INIT_PORT]--provisioner=[CA_INIT_PROVISIONER] --kms=azurekms --no-db --password-file=/opt/stepcainstall/password.txt"
    ```

    > Optionally, you can set these as codespaces user secrets. Codespaces will expose the necessary values in the matching environment variables.

3. Deploy the solution:

    ```bash
    ./deploy/deploy.sh
    ```

1. Finally, connect to your CA via Azure Bastion from a Virtual Machine with the matching private key.

    ```bash
    az extension add --name ssh
    [[ -z "${AZURE_RG_NAME}" ]] && export AZURE_RG_NAME='pki'
    az network bastion ssh -n caBastion -g $AZURE_RG_NAME \
    --auth-type ssh-key --username stepcaadmin --ssh-key ~/.ssh/id_rsa \
    --target-resource-id $(az vm show -g $AZURE_RG_NAME --name stepcadev1 -o tsv --query id)
    ```

## Configuring your CA

Consider this guidance the minimum set of steps required to stand up step-ca in a VM in Azure, using Key Vault and MySQL Backend.
Please refer to smallstep documentation and guidance for any configuration changes or guidance. For convenience, I'm adding here the documentation referenced by me while building this sample.

1. Bootstrap with DB and Key Vault
[Installation](https://smallstep.com/docs/step-ca/installation)
[Configuration](https://smallstep.com/docs/step-ca/configuration)
[Azure Key Vault](https://smallstep.com/docs/step-ca/configuration/#azure-key-vault)
[step ca init documentation](https://smallstep.com/docs/step-cli/reference/ca/init)

```bash
/opt/
```

>the schema for the keys is the following:
>azurekms:name=rootkey;vault=[CA_KEYVAULTNAME]
>azurekms:name=intermediatekey;vault=[CA_KEYVAULTNAME]



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


================
GH workflow stuff

  [[ -z "${AAD_DEPLOY_APP_NAME}" ]] && export AAD_DEPLOY_APP_NAME='pkideploy'
1. Run the solution deployment workflow.

  ```bash
  gh workflow run deploy.yml
  ```



## Requirements

- jq
- [GitHub CLI](https://cli.github.com/)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

## Documentation

<https://github.com/wasabii/step-ca-azure>
<https://smallstep.com/blog/embarrassingly-easy-certificates-on-aws-azure-gcp/>
<https://github.com/smallstep/certificates>
<https://smallstep.com/docs/step-ca/provisioners>
<https://artifacthub.io/packages/helm/smallstep/step-certificates>
<https://hub.docker.com/r/smallstep/step-ca>
<https://github.com/smallstep/autocert>

<https://smallstep.com/docs/design-document>
<https://smallstep.com/docs/step-ca/certificate-authority-server-production/#load-balancing-or-proxying-step-ca-traffic>
<https://smallstep.com/docs/step-ca/integrations>
<https://docs.microsoft.com/en-us/azure/key-vault/general/private-link-diagnostics#3-confirm-that-the-key-vault-firewall-is-properly-configured>
<https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-troubleshoot>

## Backlog

- [ ] Add High Availability to MySQL  
- [ ] Add High Availability to step-ca  
- [ ] Add VMSS base image  
- [ ] Review public access/firewall for services behind Private Endpoint  
- [ ] Try Mariner 2.0  
- [ ] Move to Generation 2 Virtual Machines  
- [ ] Add support for Managed HSM and Dedicated HSM for CA secrets  
- [ ] Add deploy to azure https://techcommunity.microsoft.com/t5/azure-governance-and-management/using-azure-templatespecs-with-a-custom-ui/ba-p/3586173
