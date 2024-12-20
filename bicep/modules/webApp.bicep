@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('App Service Plan id to host the app')
param appServicePlanId string

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

@description('Ghost container full image name and tag')
param ghostContainerImage string = 'custom-ghost-ai'

@description('Storage account name to store Ghost content files')
param storageAccountName string

@description('File share name on the storage account to store Ghost content files')
param fileShareName string

@description('Path to mount the file share in the container')
param containerMountPath string

@description('Ghost health endpoint for Load Balancer. Wait on https://github.com/TryGhost/Ghost/issues/11181 for a real one.')
param ghostHealthCheckPath string = '/admin/site'

@description('Array with the names for the environment slots')
@maxLength(19)
param environments array = [
  'staging'
]

var containerImageReference = 'DOCKER|${ghostContainerImage}:latest'
var webAppName = '${resourceGroup().name}-web-${uniqueString(resourceGroup().id)}'
var webAppDiagnosticsName = '${resourceGroup().name}-web-diag-${uniqueString(resourceGroup().id)}'

//WebApp
//-----------------------------------------------------------------------------------------------
resource webApp 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    clientAffinityEnabled: false
    serverFarmId: appServicePlanId
    httpsOnly: true
    enabled: true
    reserved: true
    siteConfig: {
      http20Enabled: false
      httpLoggingEnabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      linuxFxVersion: containerImageReference
      alwaysOn: true
      healthCheckPath: ghostHealthCheckPath
      use32BitWorkerProcess: false
      acrUseManagedIdentityCreds: true
    }
  }
}

resource siteConfig 'Microsoft.Web/sites/config@2021-01-15' = {
  parent: webApp
  name: 'web'
  properties: {
    ipSecurityRestrictions: [
      {
        ipAddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        tag: 'ServiceTag'
        priority: 300
        name: 'Access from Azure Front Door'
        description: 'Rule for access from Azure Front Door'
      }
    ]
    azureStorageAccounts: {
      ContentFilesVolume: {
        type: 'AzureFiles'
        accountName: storageAccountName
        shareName: fileShareName
        mountPath: containerMountPath
        accessKey: 'key not required'
      }
    }
  }
}

//Slots
//-----------------------------------------------------------------------------------------------
resource webAppEnvironments 'Microsoft.Web/sites/slots@2020-06-01' = [for item in environments: {
  name: '${webAppName}/${item}'
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    clientAffinityEnabled: false
    serverFarmId: appServicePlanId
    httpsOnly: true
    enabled: true
    reserved: true
    siteConfig: {
      http20Enabled: false
      httpLoggingEnabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      linuxFxVersion: containerImageReference
      alwaysOn: true
      healthCheckPath: ghostHealthCheckPath
      use32BitWorkerProcess: false
      acrUseManagedIdentityCreds: true
    }
  }
  dependsOn: [
    webApp
  ]
}]


//Diagnostics
//-----------------------------------------------------------------------------------------------
resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: webApp
  name: webAppDiagnosticsName
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
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
  }
}

output name string = webApp.name
output hostName string = webApp.properties.hostNames[0]
output outboundIpAddresses string = webApp.properties.outboundIpAddresses
output principalId string = webApp.identity.principalId
