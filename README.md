# step CA on Azure

A sample implementation of a PKI with a standalone Certificate Authority with [step-ca](https://github.com/smallstep/certificates) on Azure, leveraging Azure Key Vault, Azure MySQL (soon) and Managed Identities. Please refer to smallstep documentation for any step-ca or step cli details. For convenience, I'm adding here the documentation referenced by me while building this sample.  

* [The Design & Architecture of Smallstep](https://smallstep.com/docs/design-document)
* [Installation](https://smallstep.com/docs/step-ca/installation)  
* [Configuration](https://smallstep.com/docs/step-ca/configuration)  
* [Azure Key Vault](https://smallstep.com/docs/step-ca/configuration/#azure-key-vault)  
* [step cli init documentation](https://smallstep.com/docs/step-cli/reference/ca/init)  
* [Production considerations](https://smallstep.com/docs/step-ca/certificate-authority-server-production)
* [Integrations](https://smallstep.com/docs/step-ca/integrations)
* [Provisioners](https://smallstep.com/docs/step-ca/provisioners)

## Backlog

* [ ] Move the backlog to GitHub
* [ ] Add detailed deployment guidance, automation details and architecture diagram
  * [ ] Add feature set details and mapping to Azure services.
* [ ] Configure the [Azure Provisioner](https://smallstep.com/docs/step-ca/provisioners#azure)
* [ ] Configure the [ACME provisioner](https://smallstep.com/docs/step-ca/provisioners/#acme), [Run your own private CA & ACME server using step-ca](https://smallstep.com/blog/private-acme-server/)
* [ ] Configure the [OAuth/OIDC provider with Azure AD](https://smallstep.com/docs/step-ca/provisioners#oauthoidc-single-sign-on)
* [ ] Add client scenarios, VM, AKS, https://github.com/shibayan/keyvault-acmebot
  * [ ] [autocert](https://github.com/smallstep/autocert)
  * [ ] [Virtual Machines](https://smallstep.com/blog/embarrassingly-easy-certificates-on-aws-azure-gcp/)
  * [ ] [ACME clients](https://smallstep.com/docs/tutorials/acme-protocol-acme-clients)
  * [ ] [cert-manager](https://cert-manager.io/)
* [ ] Review public access/firewall for services behind Private Endpoint 
* [ ] Review Key Vault RBAC for minimum rights required
* [ ] Review Step provisioners and [Remote Provisioner management](https://smallstep.com/docs/step-ca/provisioners#remote-provisioner-management)
* [ ] Add MySQL as Database
  * [ ] [Use Azure Active Directory for authenticating with MySQL](https://learn.microsoft.com/en-us/azure/mysql/single-server/concepts-azure-ad-authentication)
* [ ] Test Azure Managed HSM and Azure Dedicated HSM
* [ ] Add High Availability to MySQL  
* [ ] Improve CA initialization during deployment via script or ACI.
  * [ ] Store password, ca.json and defaults.json in Key Vault.
* [ ] Add High Availability to step-ca  
* [ ] Add VMSS base image
* [ ] Azure Monitor support, metrics and logs
* [ ] Add Deploy to Azure portal experience
* [ ] [SSH and Azure AD SSO](https://smallstep.com/blog/diy-single-sign-on-for-ssh)
* [ ] AKS version [smallstep/step-ca](https://hub.docker.com/r/smallstep/step-ca) and [Helm Chart](https://artifacthub.io/packages/helm/smallstep/step-certificates)

## Deploying the solution

1. Login to your target subscription with Azure CLI and ensure it's the current default subscription.

    ```bash
    az login
    az account show -o tsv --query name
    ```

1. The following environment variables can be used by the deployment script to set the required parameter values. Please review the template for the full list of parameters that can be configured.

    | Variable   |      Default value    |  Notes |
    |-|-:|-:|
    | AZURE_RG_NAME | | Target Resource Group |
    | AZURE_LOCATION | westeurope | Target region for the deployment |
    | CA_CAVMNAME | | Virtual Machine name |
    | CA_KEYVAULTNAME | | Key Vault name |
    | CA_SSH_PUBLIC_KEY | | SSH Public Key |
    | DB_ADMIN_PASSWORD | | Database admin user password | 
    | CA_INIT_PASSWORD | | Parameter for step ca init --password-file contents |
    | CA_INIT_NAME | | CA Name |
    | CA_INIT_DNS | | The DNS fully qualified name of the CA |
    | CA_INIT_PROVISIONER_JWK | | The name of the default JWK provisioner|
    | AZURE_DNS_RESOLVER_OUTBOUND_TARGET_DNS || A json array of [targetdnsserver](https://docs.microsoft.com/en-us/rest/api/dns/dnsresolver/forwarding-rules/create-or-update?tabs=HTTP#targetdnsserver) objects.|
    | AZURE_DNS_RESOLVER_OUTBOUND_DOMAIN | | the target domain with traling dot.|
    | AZURE_DNS_PKI_ZONE | | The internal PKI domain, should match the fqdn provided for CA_INIT_DNS |

    *For more information about the CA_INIT_ parameters, please refer to the [step ca init documentation](https://smallstep.com/docs/step-cli/reference/ca/init).*  

    Variables can be exposed to the deployment script in the shell or via codespaces secrets if you use the provided codespaces container. For example:

    ```bash
    export CA_CAVMNAME="myca"
    export AZURE_LOCATION="uksouth"
    ```

1. Run the deployment script.

    ```bash
    ./deploy/deploy.sh
    ```

## Connecting to your CA

Connect to your CA via Azure Bastion from a Virtual Machine with the matching private key. The provided script depends on the last deployment to the resource group to discover the necessary parameters.

```bash
az extension add --name ssh
export AZURE_RG_NAME="pki"
export AZURE_BASTION=$(az deployment group list -g pki -o tsv --query [0].properties.parameters.bastionName.value)
export CA_ADMIN_NAME=$(az deployment group list -g pki -o tsv --query [0].properties.parameters.caVMAdminUsername.value)
export CA_VM_NAME=$(az deployment group list -g pki -o tsv --query [0].properties.parameters.caVMName.value)

az network bastion ssh -n $AZURE_BASTION -g $AZURE_RG_NAME \
  --auth-type ssh-key --username $CA_ADMIN_NAME --ssh-key ~/.ssh/id_rsa \
  --target-resource-id $(az vm show -g $AZURE_RG_NAME --name $CA_VM_NAME -o tsv --query id)
```

Once connected, you can verify the daemon state with:

```bash
systemctl status step-ca
```

## Requirements

Note: these are included in the provide dev container/codespaces.

- [GitHub CLI](https://cli.github.com/)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
