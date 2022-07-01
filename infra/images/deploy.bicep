// https://github.com/Azure/azvmimagebuilder/tree/main/quickquickstarts

param galleryName string
param location string = resourceGroup().location

param tags object = {
  provisioner: 'bicep'
  source: 'github.com/rjfmachado/bicepregistry/step-ca-azure'
}

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
