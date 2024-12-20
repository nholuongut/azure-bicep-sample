@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

@description('Service principal ID to provide access to the vault secrets for primary')
param primaryServicePrincipalId string

@description('Service principal ID to provide access to the vault secrets for secondary')
param secondaryServicePrincipalId string

var keyVaultName = '${resourceGroup().name}-kv-${uniqueString(resourceGroup().id)}'
var keyVaultDiagnosticsName = '${resourceGroup().name}-kv-diag-${uniqueString(resourceGroup().id)}'


resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: primaryServicePrincipalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: secondaryServicePrincipalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: keyVaultDiagnosticsName
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
  }
}

output keyVaultName string = keyVault.name
