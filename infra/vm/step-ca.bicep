targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/bicepregistry/step-ca-azure'
}

param caManagedIdentityName string = 'caManagedIdentity'

param pkiVirtualNetworkName string

param caKeyvaultName string
@secure()
param caSecret string

param bastionName string = 'caBastion'
param bastionSku string = 'Standard'

param dbName string
param dbLogin string = 'cadbadmin'
@secure()
param dbLoginPassword string
param dbserverEdition string = 'GeneralPurpose'
param dbskuSizeGB int = 128
param dbInstanceType string = 'Standard_D4ds_v4'
param dbhaMode string = 'ZoneRedundant'
param dbavailabilityZone string = '1'
param dbVersion string = '13'

resource caManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: caManagedIdentityName
  location: location
  tags: tags
}

resource pkiVirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: pkiVirtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'ca'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'database'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'Microsoft.DBforPostgreSQL/flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: 'keyvault'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
        }
      }
    ]
  }

  resource subnetCA 'subnets' existing = {
    name: 'ca'
  }

  resource subnetDatabase 'subnets' existing = {
    name: 'database'
  }

  resource subnetKeyvault 'subnets' existing = {
    name: 'keyvault'
  }

  resource subnetAzureBastion 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

resource pipBastion 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: bastionName
  location: location
  tags: tags
  zones: [
    '1'
    '2'
    '3'
  ]
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: bastionSku
  }
  properties: {
    dnsName: uniqueString(resourceGroup().id)
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: pkiVirtualNetwork::subnetAzureBastion.id
          }
          publicIPAddress: {
            id: pipBastion.id
          }
        }
      }
    ]
  }
}

resource caKeyvault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: caKeyvaultName
  location: location
  tags: tags
  properties: {
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: false
    publicNetworkAccess: 'disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }

  resource keyVaultSecret 'secrets@2019-09-01' = {
    name: 'caSecret'
    properties: {
      value: caSecret
    }
  }
}

resource kbPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'caKeyvault'
  location: location
  properties: {
    subnet: {
      id: pkiVirtualNetwork::subnetKeyvault.id
    }
    privateLinkServiceConnections: [
      {
        name: 'caKeyvault'
        properties: {
          privateLinkServiceId: caKeyvault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }

  resource kvPrivateEndpointDnsGroup 'privateDnsZoneGroups@2021-05-01' = {
    name: 'caKeyvault'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config1'
          properties: {
            privateDnsZoneId: keyvaultPrivateDNSZone.id
          }
        }
      ]
    }
  }
}

resource postgrePrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'private.postgres.database.azure.com'
  location: 'global'
  tags: tags
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'postgresToVirtualNetwork'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: pkiVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource keyvaultPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'keyvaultToVirtualNetwork'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: pkiVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers@2022-01-20-preview' = {
  name: dbName
  location: location
  tags: tags
  sku: {
    name: dbInstanceType
    tier: dbserverEdition
  }
  properties: {
    administratorLogin: dbLogin
    administratorLoginPassword: dbLoginPassword
    version: dbVersion
    network: {
      delegatedSubnetResourceId: pkiVirtualNetwork::subnetDatabase.id
      privateDnsZoneArmResourceId: postgrePrivateDNSZone.id
    }
    highAvailability: {
      mode: dbhaMode
    }
    storage: {
      storageSizeGB: dbskuSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    availabilityZone: dbavailabilityZone
  }
}
