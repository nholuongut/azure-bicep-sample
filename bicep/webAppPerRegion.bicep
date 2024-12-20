targetScope = 'resourceGroup'

//multi-region
@description('The region location for this setup')
param location string

@description('App Service Plan SKU')
param appServicePlanSku string = 'P1v2'

//references
@description('Analytics Id')
param logAnalyticsId string 

@description('Ghost container full image name and tag')
param ghostContainerName string

//ghost
@description('Ghost health endpoint for Load Balancer')
param ghostHealthCheckPath string

@description('Ghost content fileshare name')
param ghostContentFileShareName string

@description('Ghost content files mount path')
param ghostContentFilesMountPath string

@secure()
@description('The storage account name.')
param storageAccountName string

//lets go

module webApp './modules/webApp.bicep' = {
  name: 'webAppDeploy'
  params: {
    appServicePlanId: appServicePlan.outputs.id
    ghostContainerImage: ghostContainerName
    storageAccountName: storageAccountName
    fileShareName: ghostContentFileShareName
    containerMountPath: ghostContentFilesMountPath
    location: location
    logAnalyticsWorkspaceId: logAnalyticsId
    ghostHealthCheckPath: ghostHealthCheckPath
  }
}


module appServicePlan './modules/appServicePlan.bicep' = {
  name: 'appServicePlanDeploy'
  params: {
    appServicePlanSku: appServicePlanSku
    location: location
    logAnalyticsWorkspaceId: logAnalyticsId
  }
}

module applicationInsightsAutoScale './modules/autoScale.bicep' = {
  name: 'applicationInsightsAutoScaleDeploy'
  params: {
    appServicePlanNameId: appServicePlan.outputs.id
    logAnalyticsWorkspaceId: logAnalyticsId
    location: location
  }
}

output webAppName string = webApp.outputs.name
output webAppPrincipalId string = webApp.outputs.principalId
output webAppHostName string = webApp.outputs.hostName
output webAppOutboundIpAddresses string = webApp.outputs.outboundIpAddresses
