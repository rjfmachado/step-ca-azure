targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/bicepregistry/step-ca-azure'
}

param galleryDeploy bool = false
param virtualNetworkDeploy bool = true
param dnsResolverDeploy bool = false
param keyvaultDeploy bool = true
param bastionDeploy bool = true
param databaseDeploy bool = false
param caDeploy bool = true

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

param virtualNetworkName string = 'stepca'
param virtualNetworkDNSServers array = []

param dnsResolverName string = 'dnsresolver'
param dnsResolverOutboundDNS array
param dnsResolverOutboundDNSDomainName string

param keyvaultName string
//@secure()

param bastionName string = 'caBastion'
param bastionSku string = 'Standard'

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
param caPort int = 443
param caVMCustomData string = loadTextContent('cloudinit.yaml')
param caSTEP_CA_VERSION string = '0.22.1'
param caSTEP_CLI_VERSION string = '0.22.0'
param ca_INIT_NAME string
param ca_INIT_DNS string
param ca_INIT_PORT string = ':443'
param ca_INIT_ROOT_KEY_NAME string = 'root'
param ca_INIT_INTERMEDIATE_KEY_NAME string = 'intermediate'

param ca_INIT_PROVISIONER_JWT string

@secure()
param ca_INIT_PASSWORD string

@description('The image reference. please select a debian/ubuntu based step-ca supported OS with systemd version 245 or greater.')
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
        keyData: caDeploy ? caPublicSshKey.properties.publicKey : null
      }
    ]
  }
}

//load the cloudinit template and perform template replacements
var cloudinit0 = caVMCustomData
var cloudinit1 = replace(cloudinit0, '[STEP_CA_VERSION]', caSTEP_CA_VERSION)
var cloudinit2 = replace(cloudinit1, '[STEP_CLI_VERSION]', caSTEP_CLI_VERSION)
var cloudinit3 = replace(cloudinit2, '[caVMAdminUsername]', caVMAdminUsername)
var cloudinit4 = replace(cloudinit3, '[AZURE_CLIENT_ID]', caDeploy ? caManagedIdentity.properties.clientId : '')
var cloudinit5 = replace(cloudinit4, '[CA_KEYVAULTNAME]', keyvaultName)
var cloudinit6 = replace(cloudinit5, '[CA_ROOT_KEY_NAME]', ca_INIT_ROOT_KEY_NAME)
var cloudinit7 = replace(cloudinit6, '[CA_INT_KEY_NAME]', ca_INIT_INTERMEDIATE_KEY_NAME)
var cloudinit8 = replace(cloudinit7, '[CA_INIT_NAME]', ca_INIT_NAME)
var cloudinit9 = replace(cloudinit8, '[CA_INIT_DNS]', ca_INIT_DNS)
var cloudinit10 = replace(cloudinit9, '[CA_INIT_PORT]', ca_INIT_PORT)
var cloudinit11 = replace(cloudinit10, '[CA_INIT_PROVISIONER_JWT]', ca_INIT_PROVISIONER_JWT)
var cloudinit = cloudinit11

resource virtualnetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = if (virtualNetworkDeploy) {
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
        name: 'dns'
        properties: {
          addressPrefix: '10.0.254.0/24'
          delegations: [
            {
              name: 'Microsoft.Network/dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]

        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.253.0/24'
        }
      }
      {
        name: 'ca'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'database'
        properties: {
          addressPrefix: '10.0.2.0/24'
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
          addressPrefix: '10.0.3.0/24'
        }
      }
    ]
  }
  resource subnetAzureBastion 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }

  resource subnetDns 'subnets' existing = {
    name: 'dns'
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

resource bastionPip 'Microsoft.Network/publicIPAddresses@2022-01-01' = if (bastionDeploy) {
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
            id: virtualnetwork::subnetAzureBastion.id
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

resource keyvault 'Microsoft.KeyVault/vaults@2022-07-01' = if (keyvaultDeploy) {
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
}

resource keyvaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = if (keyvaultDeploy) {
  name: 'caKeyvault'
  location: location
  dependsOn: [
    keyvaultPrivateDNSZone::linkVirtualNetwork
  ]
  properties: {
    subnet: {
      id: virtualnetwork::subnetKeyvault.id
    }
    privateLinkServiceConnections: [
      {
        name: 'caKeyvault'
        properties: {
          privateLinkServiceId: keyvault.id
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
        id: virtualnetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource keyvaultAdminrole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
}

resource mysql 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = if (databaseDeploy) {
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
      delegatedSubnetResourceId: virtualnetwork::subnetDatabase.id
      privateDnsZoneResourceId: mysqlPrivateDNSZone.id
    }
  }
}

resource mysqlPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (databaseDeploy) {
  name: 'privatelink.mysql.database.azure.com'
  location: 'global'
  tags: tags
  properties: {}

  resource linkVirtualNetwork 'virtualNetworkLinks@2020-06-01' = {
    name: 'postgresToVirtualNetwork'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualnetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource mysqlManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if (databaseDeploy) {
  name: dbManagedIdentityName
  location: location
  tags: tags
}

resource gallery 'Microsoft.Compute/galleries@2022-01-03' = if (galleryDeploy) {
  name: galleryName
  location: location
  tags: tags
  properties: {
    description: 'Host step-ca images for VMSS deployment.'
  }
}

resource galleryManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if (galleryDeploy) {
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
    principalId: galleryDeploy ? galleryManagedIdentity.properties.principalId : ''
    roleDefinitionId: galleryImageBuilderRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

resource imageDefinitionCA 'Microsoft.Compute/galleries/images@2022-01-03' = if (galleryDeploy) {
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

resource caPublicSshKey 'Microsoft.Compute/sshPublicKeys@2022-03-01' = if (caDeploy) {
  name: 'caVMSSHKey'
  location: location
  tags: tags
  properties: {
    publicKey: caVMPublicSshKey
  }
}

resource caManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if (caDeploy) {
  name: caManagedIdentityName
  location: location
  tags: tags
}

resource cavmnic 'Microsoft.Network/networkInterfaces@2022-01-01' = if (caDeploy) {
  name: '${caVMName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: virtualnetwork::subnetCA.id
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

resource cavmnsg 'Microsoft.Network/networkSecurityGroups@2021-03-01' = if (caDeploy) {
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
          destinationPortRange: '${caPort}'
        }
      }
    ]
  }
}

resource cavm 'Microsoft.Compute/virtualMachines@2022-03-01' = if (caDeploy) {
  name: caVMName
  location: location
  tags: tags
  dependsOn: [
    keyvault
    cavmkeyvaultadmin
  ]
  identity: caDeploy ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${caManagedIdentity.id}': {}
    }
  } : null
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

  resource caInitPassword 'extensions@2022-03-01' = {
    name: 'caInitPassword'
    location: location
    properties: {
      publisher: 'microsoft.azure.extensions'
      type: 'CustomScript'
      typeHandlerVersion: '2.1'
      autoUpgradeMinorVersion: true
      protectedSettings: {
        commandToExecute: 'echo "${ca_INIT_PASSWORD}" > /opt/stepcainstall/password.txt'
      }
    }
  }
}

resource cavmkeyvaultadmin 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (caDeploy) {
  name: guid(resourceGroup().id, subscription().id, 'Key Vault Administrator')
  scope: keyvault
  properties: {
    principalId: caDeploy ? caManagedIdentity.properties.principalId : ''
    roleDefinitionId: keyvaultAdminrole.id
    principalType: 'ServicePrincipal'
  }
}

resource privateresolver 'Microsoft.Network/dnsResolvers@2020-04-01-preview' = if (virtualNetworkDeploy && dnsResolverDeploy) {
  name: dnsResolverName
  location: location
  properties: {
    virtualNetwork: {
      id: virtualnetwork.id
    }
  }

  resource outboundEndpoints 'outboundEndpoints@2020-04-01-preview' = {
    name: 'external'
    location: location
    properties: {
      subnet: {
        id: virtualnetwork::subnetDns.id
      }
    }
  }
}

resource dnsForwardRules 'Microsoft.Network/dnsForwardingRulesets@2020-04-01-preview' = if (virtualNetworkDeploy && dnsResolverDeploy) {
  name: 'external'
  location: location
  properties: {
    dnsResolverOutboundEndpoints: [
      {
        id: privateresolver::outboundEndpoints.id
      }
    ]
  }

  resource outbound 'forwardingRules@2020-04-01-preview' = {
    name: 'outbound'
    properties: {
      targetDnsServers: dnsResolverOutboundDNS
      domainName: dnsResolverOutboundDNSDomainName
    }
  }

  resource networkLink 'virtualNetworkLinks@2020-04-01-preview' = {
    name: 'outbound'
    properties: {
      virtualNetwork: {
        id: virtualnetwork.id
      }
    }
  }
}

output caManagedIdentityClientId string = caDeploy ? caManagedIdentity.properties.clientId : ''
output caCloudInit string = cloudinit
