targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/bicepregistry/step-ca-azure'
}

param galleryName string
param galleryManagedIdentityName string = 'galleryManagedIdentity'

param imageName string = 'stepca'
param imageDescription string = 'step-ca on ubuntu linux'
param imageIdentifier object
param imageGeneration string = 'V1'
param imageRecommended object

param pkiVirtualNetworkName string

param caKeyvaultName string
//@secure()
//param caSecret string

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

param caVMName string
param caVMAdminUsername string

@description('SSH Key')
@secure()
param caVMPublicSshKey string

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version.')
param caVMOSVersion string = '18.04-LTS'
param caVMSize string = 'Standard_B2s'

param caManagedIdentityName string = 'caManagedIdentity'

var caVMlinuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${caVMAdminUsername}/.ssh/authorized_keys'
        keyData: caPulicSshKey.properties.publicKey
      }
    ]
  }
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

resource bastion 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: bastionSku
  }
  properties: {
    dnsName: uniqueString(resourceGroup().id)
    enableTunneling: true
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

  // resource keyVaultSecret 'secrets@2019-09-01' = {
  //   name: 'caSecret'
  //   properties: {
  //     value: caSecret
  //   }
  // }
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

resource galleryManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: galleryManagedIdentityName
  location: location
  tags: tags
}

resource galleryImageBuilderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
  name: guid(resourceGroup().id, subscription().id, 'Image Builder Service Image Contributor')
  properties: {
    roleName: 'Image Builder Service Image Contributor'
    description: 'Image Builder access to create resources for the image build, you should delete or split out as appropriate'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/galleries/read'
          'Microsoft.Compute/galleries/images/read'
          'Microsoft.Compute/galleries/images/versions/read'
          'Microsoft.Compute/galleries/images/versions/write'
          'Microsoft.Compute/images/write'
          'Microsoft.Compute/images/read'
          'Microsoft.Compute/images/delete'
        ]
        notActions: []
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}

resource galleryImageBuilderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, subscription().id, 'Image Builder Service Image Contributor')
  scope: gallery
  properties: {
    principalId: galleryManagedIdentity.properties.principalId
    roleDefinitionId: galleryImageBuilderRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

resource stepcaImageDefinition 'Microsoft.Compute/galleries/images@2022-01-03' = {
  name: imageName
  location: location
  tags: tags
  parent: gallery
  properties: {
    architecture: 'x64'
    description: imageDescription
    hyperVGeneration: imageGeneration
    identifier: imageIdentifier
    osState: 'Generalized'
    osType: 'Linux'
    recommended: imageRecommended
  }
}

resource caPulicSshKey 'Microsoft.Compute/sshPublicKeys@2022-03-01' = {
  name: 'caVMSSHKey'
  location: location
  tags: tags
  properties: {
    publicKey: caVMPublicSshKey
  }
}

resource caManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: caManagedIdentityName
  location: location
  tags: tags
}

resource cavmnic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${caVMName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: pkiVirtualNetwork::subnetCA.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: cavmnsg.id
    }
  }
}

resource cavmnsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${caVMName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'CA'
        properties: {
          priority: 1001
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '9000'
        }
      }
    ]
  }
}

resource cavm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: caVMName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${caManagedIdentity.id}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: caVMSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
      }

      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: caVMOSVersion
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: cavmnic.id
        }
      ]
    }
    osProfile: {
      computerName: caVMName
      adminUsername: caVMAdminUsername
      linuxConfiguration: caVMlinuxConfiguration
    }
  }
}

resource keyvaultAdminrole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
}

resource cavmkeyvaultadmin 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Administrator')
  scope: caKeyvault
  properties: {
    principalId: caManagedIdentity.properties.principalId
    roleDefinitionId: keyvaultAdminrole.id
    principalType: 'ServicePrincipal'
  }
}
