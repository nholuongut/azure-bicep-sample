@description('Location for resources.')
param location string = 'centralus'

@description('The SKU for the Container Registry.')
param containerRegistrySku string = 'Premium'

@description('Ghost container full image name and tag')
param ghostContainerName string = 'custom-ghost-ai:latest'

var containerRegistryName = replace('${resourceGroup().name}-cr-${uniqueString(resourceGroup().id)}', '-', '')

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: containerRegistrySku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }

    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }

    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    anonymousPullEnabled: false
  }
}

output containerRegistryName string = containerRegistryName 
output registryUrl string = 'https://${containerRegistry.properties.loginServer}' 
output ghostContainerName string = ghostContainerName
