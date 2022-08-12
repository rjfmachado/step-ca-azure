targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/bicepregistry/step-ca-azure'
}

param galleryDeploy bool = false
param galleryName string = 'stepca'
param galleryManagedIdentityName string = 'galleryManagedIdentity'

param imageName string = 'stepca'
param imageDescription string = 'step-ca on ubuntu linux'
param imageIdentifier object = {
  publisher: 'sample'
  offer: 'step-ca'
  sku: 'standalone'
}
param imageGeneration string = 'V2'
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

param virtualNetworkDeploy bool = true
param virtualNetworkName string = 'stepca'
param virtualNetworkDNSServers array = []

param keyvaultDeploy bool = true
param keyvaultName string
//@secure()
//param caSecret string

// Bastion host name
param bastionDeploy bool = true
param bastionName string = 'caBastion'
param bastionSku string = 'Standard'

param dbDeploy bool = false
param dbName string = 'stepca'
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

// CA Virtual Machine Parameters
param caVMName string
param caVMAdminUsername string = 'stepcaadmin'
@description('SSH Key')
@secure()
param caVMPublicSshKey string
param caVMCustomData string = loadTextContent('cloudinit.yaml')

param caSTEP_CA_VERSION string = '0.21.0'
param caSTEP_CLI_VERSION string = '0.21.0'

@description('The image reference. please select a step-ca supported OS with systemd version 245 or greater.')
param caVMImageReference object = {
  publisher: 'Debian'
  offer: 'debian-11'
  sku: '11-gen2'
  version: 'latest'
}
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

var cloudinit1 = replace(caVMCustomData, '[STEP_CA_VERSION]', caSTEP_CA_VERSION)
var cloudinit2 = replace(cloudinit1, '[STEP_CLI_VERSION]', caSTEP_CLI_VERSION)
var cloudinit3 = replace(cloudinit2, '[caVMAdminUsername]', caVMAdminUsername)
var cloudinit4 = replace(cloudinit3, '[AZURE_CLIENT_ID]', caManagedIdentity.properties.clientId)
var cloudinit = cloudinit4

resource pkiVirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = if (virtualNetworkDeploy) {
  name: virtualNetworkName
  location: location
  properties: {
    dhcpOptions: {
      dnsServers: virtualNetworkDNSServers
    }
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

resource pipBastion 'Microsoft.Network/publicIPAddresses@2021-05-01' = if (bastionDeploy) {
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

resource bastion 'Microsoft.Network/bastionHosts@2022-01-01' = if (bastionDeploy) {
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

resource caKeyvault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = if (keyvaultDeploy) {
  name: keyvaultName
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

resource keyvaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = if (keyvaultDeploy) {
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

  resource kvPrivateEndpointDnsGroup 'privateDnsZoneGroups@2021-05-01' = if (keyvaultDeploy) {
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

resource keyvaultPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (keyvaultDeploy) {
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

resource mysqlPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (dbDeploy) {
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

resource dbManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if (dbDeploy) {
  name: dbManagedIdentityName
  location: location
  tags: tags
}

resource mysql 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = if (dbDeploy) {
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

resource gallery 'Microsoft.Compute/galleries@2022-01-03' = if (galleryDeploy) {
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

resource galleryImageBuilderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = if (galleryDeploy) {
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

resource galleryImageBuilderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (galleryDeploy) {
  name: guid(resourceGroup().id, subscription().id, 'Image Builder Service Image Contributor')
  scope: gallery
  properties: {
    principalId: galleryManagedIdentity.properties.principalId
    roleDefinitionId: galleryImageBuilderRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

resource stepcaImageDefinition 'Microsoft.Compute/galleries/images@2022-01-03' = if (galleryDeploy) {
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

      imageReference: caVMImageReference
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
      customData: base64(cloudinit)
    }
  }

  // resource runPowerShellScript 'runCommands@2022-03-01' = {
  //   name: 'installjq'
  //   location: location
  //   properties: {
  //     source: {
  //       script: 'apt update && apt install -y jq'
  //     }
  //     timeoutInSeconds: 60
  //   }
  // }
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

output caManagedIdentityClientId string = caManagedIdentity.properties.clientId
output caCloudInit string = cloudinit
