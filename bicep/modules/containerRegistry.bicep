@description('Location for resources.')
param location string = resourceGroup().location

@description('The SKU for the Container Registry.')
param containerRegistrySku string = 'Premium'

@description('Service principal ID to provide access to the vault secrets for the primary web app')
param primaryServicePrincipalId string

@description('Service principal ID to provide access to the vault secrets for the secondary web app')
param secondaryServicePrincipalId string

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsId string

@description('ACR name must be known to other flows too, so it has to come as input.')
param containerRegistryName string 

@description('Roles are not idempotent, changes must be manual')
param isInitialSetup bool

var containerRegistryRoleAssignment1Name = guid('${resourceGroup().name}-cr-role1-${uniqueString(resourceGroup().id)}')
var containerRegistryRoleAssignment2Name = guid('${resourceGroup().name}-cr-role2-${uniqueString(resourceGroup().id)}')
var containerRegistryDiagnosticsName = replace('${resourceGroup().name}-cr-diag-${uniqueString(resourceGroup().id)}', '-', '')

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
      defaultAction: 'Allow'
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
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Enabled'
    anonymousPullEnabled: false

  }
}

resource containerRegistryRoleAssignment1 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isInitialSetup) {
  name: containerRegistryRoleAssignment1Name
  scope: containerRegistry
  properties: {
    principalId: primaryServicePrincipalId
    principalType:'ServicePrincipal'
    //AcrPull: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
    //roleDefinitionId: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/scope-extension-resources
    //roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') 
  }
}

resource containerRegistryRoleAssignment2 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isInitialSetup) {
  name: containerRegistryRoleAssignment2Name
  scope: containerRegistry
  properties: {
    principalId: secondaryServicePrincipalId
    principalType:'ServicePrincipal'
    //AcrPull: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
    //roleDefinitionId: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/scope-extension-resources
    //roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') 
  }
}


resource containerRegistryDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: containerRegistry
  name: containerRegistryDiagnosticsName
  properties: {
    workspaceId: logAnalyticsId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs:[
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
      }
      {
        category: 'ContainerRegistryLoginEvents'
        enabled: true
      }
    ]
  }
}

output registryUrl string = 'https://${containerRegistry.properties.loginServer}' 
