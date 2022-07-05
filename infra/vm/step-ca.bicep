targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/bicepregistry/step-ca-azure'
}

param galleryName string

param imageName string = 'stepca'
param imageDescription string = 'step-ca on ubuntu linux'
param imageIdentifier object = {
  publisher: 'github/rjfmachado'
  offer: 'step-ca'
  sku: '0.20.0'
}
param imageRecommended object = {
  memory: {
    max: 32768
    min: 2048
  }
  vCPUs: {
    max: 16
    min: 2
  }
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
param dbManagedIdentityName string = 'dbManagedIdentity'
param dbSku object = {
  name: 'Standard_B2s'
  tier: 'Burstable'
}
param dbHighAvailability object = {
  mode: 'Disabled'
}
param dbVersion string = '5.7'

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
              name: 'Microsoft.DBforMySQL/flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforMySQL/flexibleServers'
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
  dependsOn: [
    keyvaultPrivateDNSZone
  ]
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

resource keyvaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'caKeyvault'
  location: location
  dependsOn: [
    keyvaultPrivateDNSZone::linkVirtualNetwork
  ]
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

resource keyvaultPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
  properties: {}

  resource linkVirtualNetwork 'virtualNetworkLinks@2020-06-01' = {
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

resource mysqlPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.mysql.database.azure.com'
  location: 'global'
  tags: tags
  properties: {}

  resource linkVirtualNetwork 'virtualNetworkLinks@2020-06-01' = {
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

resource dbManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: dbManagedIdentityName
  location: location
  tags: tags
}

resource mysql 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = {
  name: dbName
  location: location
  tags: tags
  sku: dbSku
  dependsOn: [
    mysqlPrivateDNSZone::linkVirtualNetwork
  ]
  properties: {
    administratorLogin: dbLogin
    administratorLoginPassword: dbLoginPassword
    version: dbVersion
    highAvailability: dbHighAvailability
    network: {
      delegatedSubnetResourceId: pkiVirtualNetwork::subnetDatabase.id
      privateDnsZoneResourceId: mysqlPrivateDNSZone.id
    }
  }
}

resource gallery 'Microsoft.Compute/galleries@2022-01-03' = {
  name: galleryName
  location: location
  tags: tags
  properties: {
    description: 'Host step-ca images for VMSS deployment.'
  }
}

resource stepcaImage 'Microsoft.Compute/galleries/images@2022-01-03' = {
  name: imageName
  location: location
  tags: tags
  parent: gallery
  properties: {
    architecture: 'x64'
    description: imageDescription
    hyperVGeneration: 'V2'
    identifier: imageIdentifier
    osState: 'Generalized'
    osType: 'Linux'
    recommended: imageRecommended
  }
}
