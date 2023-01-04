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
param imageRecommended object

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

param caVMName string
param caVMAdminUsername string

@description('SSH Key')
@secure()
param caVMsshKey string

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version.')
param caVMOSVersion string = '18.04-LTS'
param caVMSize string = 'Standard_B2s'

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

resource stepcaImageDefinition 'Microsoft.Compute/galleries/images@2022-01-03' = {
  name: imageName
  location: location
  tags: tags
  parent: gallery
  properties: {
    architecture: 'x64'
    description: imageDescription
    hyperVGeneration: 'V1'
    identifier: imageIdentifier
    osState: 'Generalized'
    osType: 'Linux'
    recommended: imageRecommended
  }
}

resource stepcaImageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
  name: imageName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${galleryManagedIdentity.id}': {}
    }
  }
  properties: {
    buildTimeoutInMinutes: 80
    vmProfile: {
      vmSize: 'Standard_B2s'
      osDiskSizeGB: 30
    }
    source: {
      type: 'PlatformImage'
      publisher: 'Canonical'
      offer: 'UbuntuServer'
      sku: caVMOSVersion
      version: 'latest'
    }
    distribute: [
      {
        type: 'SharedImage'
        galleryImageId: stepcaImageDefinition.id
        runOutputName: 'step-ca-ubuntu-18-04'
        replicationRegions: [
          location
        ]
      }
    ]
    customize: [
      {
        type: 'Shell'
        name: 'Enable auto-update'
        inline: [
          'sudo apt install unattended-upgrades'
        ]
      }
    ]
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
