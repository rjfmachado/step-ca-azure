# step-ca-azure

An implementation of step-ca on Azure.

## Deploying the solution

> Guidance/Scripts are Linux/bash and tested on the included GitHub codespaces.

1. Verify the GitHub cli can access your GitHub account and project repository

  ```bash
  gh repo view
  ```

1. Login to your target subscription with Azure CLI and ensure it's the current default subscription.

  ```bash
  az login
  az account show -o tsv --query name
  ```

1. Optionally, generate an SSH key to access the CA. If you do not, you have to bring your ssh key pair to the codespaces environment.

  ```bash
  ssh-keygen -t rsa -b 4096 -o -a 100
  ```

1. Set the target Resource Group by configuring the environment variable AZURE_RG_NAME (default:pki).  
Set the target Azure Region by configuring the environment variable AZURE_LOCATION (default:westeurope).  
Set the Azure AD Application names for the deployment credential (default: pkideploy)
Set the path to the SSH public key used to login to the CA (default: pkideploy).

  ```bash
  export AZURE_RG_NAME='pki'
  export AZURE_LOCATION='westeurope'
  export AAD_DEPLOY_APP_NAME='pkideploy'
  export SSH_PUBLIC_KEY_PATH='~/.ssh/id_rsa.pub'
  ```

1. Run the deployment pre-requisites script.

  ```bash
  ./deploy/deploy.sh
  ```

1. Run the solution deployment workflow.

  ```bash
  gh workflow run deploy.yml
  ```

1. Finally, connect to your CA via the Jump Host

```bash
vmid=$(az vm show -g $AZURE_RG_NAME --name stepcadev1 -o tsv --query id)
az network bastion ssh -n caBastion -g $AZURE_RG_NAME \
   --auth-type ssh-key --username stepcaadmin --ssh-key ~/.ssh/id_rsa \
   --target-resource-id $vmid
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
