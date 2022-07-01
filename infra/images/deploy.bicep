param galleryName string
param location string = resourceGroup().location

param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/bicepregistry/step-ca-azure'
}

resource gallery 'Microsoft.Compute/galleries@2022-01-03' = {
  name: galleryName
  location: location
  tags: tags
  properties: {
    description: 'Host step-ca images for VMSS deployment.'
  }
}
