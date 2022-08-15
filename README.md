# step-ca-azure

A sample implementation of step-ca on Azure leveraging Azure Key Vault, Azure MySQL and Managed Identities.

> The below guidance has been designed and tested on the included GitHub codespaces environment.

## Deploying the solution

1. Login to your target subscription with Azure CLI and ensure it's the current default subscription.

    ```bash
    az login
    az account show -o tsv --query name
    ```

1. This guidance and provided github workflows expect the following environment variables to be present:

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

    Variables can be exposed to the deployment script in the shell, via codespaces secrets if you use the provided codespaces container or via repository secrets if you use the provided deployment workflows (not there yet). For example:

    ```bash
    export CA_INIT_COMMAND="step ca init --deployment-type=standalone --name=[CA_INIT_NAME] --dns=[CA_INIT_DNS] --address=[CA_INIT_PORT]--provisioner=[CA_INIT_PROVISIONER] --kms=azurekms --no-db --password-file=/opt/stepcainstall/password.txt"
    export CA_CAVMNAME="myca"
    export AZURE_LOCATION="westeurope"
    ```

    Run the deployment script after setting all the required variables.

    ```bash
    ./deploy/deploy.sh
    ```

## Initializing your CA

Connect to your CA via Azure Bastion from a Virtual Machine with the matching private key. Replace the appropriate parameters.

    ```bash
    az extension add --name ssh
    [[ -z "${AZURE_RG_NAME}" ]] && export AZURE_RG_NAME="pki"
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

Your [CA_INIT_COMMAND] and [CA_INIT_PASSWORD] have been placed in /opt/stepcainstall/ as initstepca.sh and password.txt. You can run the script to initialize your CA.

```bash
/opt/stepcainstall/initstepca.sh
```

>the schema for the keys is the following:  
>azurekms:name=rootkey;vault=[CA_KEYVAULTNAME]  
>azurekms:name=intermediatekey;vault=[CA_KEYVAULTNAME]

https://github.com/smallstep/cli/issues/721

1. setup the daemon
https://smallstep.com/docs/step-ca/certificate-authority-server-production#running-step-ca-as-a-daemon
insert Environment=AZURE_CLIENT_ID=<guid> in /etc/systemd/system/step-ca.service

TODO:
https://github.com/smallstep/step-kms-plugin
https://raw.githubusercontent.com/smallstep/certificates/master/examples/pki/config/ca.json
https://smallstep.com/docs/step-ca/provisioners#remote-provisioner-management

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

- [ ] Review public access/firewall for services behind Private Endpoint 
- [ ] Review Key Vault RBAC
- [ ] Add MySQL as Database
- [ ] Add High Availability to MySQL  
- [ ] Add High Availability to step-ca  
- [ ] Add VMSS base image  
 
- [ ] Try Mariner 2.0  
- [x] Move to Generation 2 Virtual Machines  
- [ ] Add support for Managed HSM and Dedicated HSM for CA secrets  
- [ ] Add deploy to azure experience <https://techcommunity.microsoft.com/t5/azure-governance-and-management/using-azure-templatespecs-with-a-custom-ui/ba-p/3586173>
