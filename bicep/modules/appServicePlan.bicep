@description('App Service Plan pricing tier')
@allowed([
  'P1v2'
  'P2v2'
  'P3v2'
])
param appServicePlanSku string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

var appServicePlanName = '${resourceGroup().name}-asp-${uniqueString(resourceGroup().id)}'
var appServicePlanDiagnosticsName = '${resourceGroup().name}-asp-diag-${uniqueString(resourceGroup().id)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  properties: {
    reserved: true
    zoneRedundant: true
  }
  sku: {
    name: appServicePlanSku
  }
}

resource appServicePlanDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appServicePlan
  name: appServicePlanDiagnosticsName
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output id string = appServicePlan.id
