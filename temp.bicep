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

// {
//         name: 'database'
//         properties: {
//           addressPrefix: '10.0.1.0/24'
//           delegations: [
//             {
//               name: 'Microsoft.DBforPostgreSQL/flexibleServers'
//               properties: {
//                 serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
//               }
//             }
//           ]
//         }
//       }

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
