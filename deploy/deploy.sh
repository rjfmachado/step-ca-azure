[[ -z "${AZURE_RG_NAME}" ]] && export AZURE_RG_NAME='pki'
[[ -z "${AZURE_LOCATION}" ]] && export AZURE_LOCATION='westeurope'
[[ -z "${AZURE_DNS_RESOLVER_OUTBOUND_TARGET_DNS}" ]] && export AZURE_DNS_RESOLVER_OUTBOUND_TARGET_DNS="[{\"ipAddress\": \"192.168.0.11\"},{\"ipAddress\": \"192.168.0.13\"}]"
[[ -z "${AZURE_DNS_RESOLVER_OUTBOUND_DOMAIN}" ]] && export AZURE_DNS_RESOLVER_OUTBOUND_DOMAIN='test.com.'
[[ -z "${CA_INIT_DNS}" ]] && export CA_INIT_DNS='your DNS fqdn'
[[ -z "${CA_SSH_PUBLIC_KEY}" ]] && export CA_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
[[ -z "${DB_ADMIN_PASSWORD}" ]] && export DB_ADMIN_PASSWORD='your Database admin password'
[[ -z "${CA_INIT_NAME}" ]] && export CA_INIT_NAME='your CA Name'
[[ -z "${CA_INIT_DNS}" ]] && export CA_INIT_DNS='your DNS fqdn'
[[ -z "${CA_INIT_PROVISIONER_JWT}" ]] && export CA_INIT_PROVISIONER_JWT="$(az account show -o tsv --query user.name)"

az group create --name $AZURE_RG_NAME --location $AZURE_LOCATION -o none
az deployment group create -g $AZURE_RG_NAME -o none \
  --template-file infra/base/step-ca-infra.bicep \
  --parameters caVMName="$CA_CAVMNAME" \
  --parameters keyvaultName="$CA_KEYVAULTNAME" \
  --parameters caVMPublicSshKey="$CA_SSH_PUBLIC_KEY" \
  --parameters ca_INIT_PROVISIONER_JWT="$CA_INIT_PROVISIONER_JWT" \
  --parameters ca_INIT_PASSWORD="$CA_INIT_PASSWORD" \
  --parameters ca_INIT_NAME="$CA_INIT_NAME" \
  --parameters ca_INIT_DNS="$CA_INIT_DNS" \
  --parameters dbLoginPassword="$DB_ADMIN_PASSWORD" \
  --parameters dnsResolverOutboundTargetDNS="$AZURE_DNS_RESOLVER_OUTBOUND_TARGET_DNS" \
  --parameters dnsResolverOutboundDNSDomainName="$AZURE_DNS_RESOLVER_OUTBOUND_DOMAIN"