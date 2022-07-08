# step-ca-azure

An implementation of step-ca on Azure.

# Deploying the solution

> Guidance/Scripts are Linux/bash.

1. Configure the GitHub cli to access your GitHub account.
2. Login to your target subscription with Azure CLI and ensure it's the current default subscription.
  ```bash
  az account show -o json --query name
  ```
3. Set the target Resource Group by configuring the environment variable AZURE_RG_NAME (default:pki).  
Set the target Azure Region by configuring the environment variable AZURE_LOCATION (default:westeurope).  
Set the Azure AD Application names for the deployment credential (default: pkideploy)
Set the path to the SSH public key used to login to the CA (default: pkideploy).  
  ```bash
  export AZURE_RG_NAME='pki'
  export AZURE_LOCATION='westeurope'
  export AAD_DEPLOY_APP_NAME='pkideploy'
  export SSH_PUBLIC_KEY_PATH='~/.ssh/id_rsa.pub'
  ```

6. Run the deployment pre-requisites script
  ```bash
  ./deploy/deploy.sh
  ```

7. Run the solution deployment workflow
  ```bash
  gh workflow run deploy.yml
  ```

8. Optionally, run the individual module deployment workflows
  ```
  gh workflow run
  ```

## Requirements

- jq
- [GitHub CLI](https://cli.github.com/)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

## Documentation

[ ] https://github.com/wasabii/step-ca-azure
[ ] https://smallstep.com/blog/embarrassingly-easy-certificates-on-aws-azure-gcp/
[ ] https://github.com/smallstep/certificates
[ ] https://smallstep.com/docs/step-ca/provisioners
[ ] https://artifacthub.io/packages/helm/smallstep/step-certificates
[ ] https://hub.docker.com/r/smallstep/step-ca
[ ] https://github.com/smallstep/autocert

[ ] https://smallstep.com/docs/design-document
[ ] https://smallstep.com/docs/step-ca/certificate-authority-server-production/#load-balancing-or-proxying-step-ca-traffic
[ ] https://smallstep.com/docs/step-ca/certificate-authority-server-production#high-availability

[ ] https://smallstep.com/docs/step-ca/integrations

[ ] https://docs.microsoft.com/en-us/azure/key-vault/general/private-link-diagnostics#3-confirm-that-the-key-vault-firewall-is-properly-configured

[ ] https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-troubleshoot

## Backlog

[ ] Add High Availability to MySQL  
[ ] Add High Availability to step-ca  
[ ] Add VMSS base image  
[ ] Review public access/firewall for services behind Private Endpoint  
[ ] Try Mariner 2.0  
[ ] Move to Generation 2 Virtual Machines  
[ ] Add support for Managed HSM and Dedicated HSM for CA secrets  