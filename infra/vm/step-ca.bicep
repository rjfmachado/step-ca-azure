targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/bicepregistry/step-ca-azure'
}

param caManagedIdentityName string = 'caManagedIdentity'

param pkiVirtualNetworkName string

param caKeyvaultName string

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
    enableSoftDelete: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource postgrePrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'postgres.database.azure.com'
  location: 'global'
  tags: tags
  properties: {}
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
