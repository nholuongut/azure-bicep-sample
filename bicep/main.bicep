targetScope = 'subscription'

@description('Prefix for all resources')
param applicationNamePrefix string = 'ds'

//multi-region
@description('The primary region location')
param primaryLocation string = 'centralus'

@description('A resource group suffix for the primary resource group')
param primaryResourceGroupSuffix string = '1'

@description('The secondary region location')
param secondaryLocation string = 'eastus'

@description('A resource group suffix for the secondary resource group')
param secondaryResourceGroupSuffix string = '2'

@description('The region location for the common resource group')
param commonLocation string = 'centralus'

@description('A resource group suffix for the common resource group')
param commonResourceGroupSuffix string = 'c'

//SKU
@description('App Service Plan SKU')
param appServicePlanSku string = 'P1v2'

@description('MySQL SKU')
param mySQLServerSku string = 'GP_Gen5_4'

@description('Analytics SKU')
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('The SKU for the frontdoor. Current setup is for premium.')
param frontDoorSku string = 'Premium_AzureFrontDoor'

@description('The SKU for the Container Registry.')
param containerRegistrySku string = 'Premium'

@description('Storage Account SKU Code')
param storageAccountSku string = 'Standard_GZRS'

//container
@description('Ghost container full image name and tag')
param ghostContainerName string = 'custom-ghost-ai'

//MySQL
@description('MySQL username.')
param databaseUser string = 'ghost'

@description('MySQL database name.')
param databaseName string = 'ghost'

@description('MySQL server password.')
@secure()
param databasePassword string

//ghost
@description('Ghost health endpoint for Load Balancer. Wait on https://github.com/TryGhost/Ghost/issues/11181 for a real one.')
param ghostHealthCheckPath string= '/admin/site'

@description('Ghost content fileshare name.')
param ghostContentFileShareName string= 'contentfiles'

@description('Ghost content files mount path.')
param ghostContentFilesMountPath string= '/var/lib/ghost/content_files'

@description('Setup for non idempotent resources')
param isInitialSetup bool = false

@description('ACR name must be known to other flows too, so it has to come as input.')
param containerRegistryName string  = 'dscr5sdslxc2tc2qa'

//Common Resource Group
//----------------------------------------------------------------------------------------------------------
var commonResourceGroupName = '${applicationNamePrefix}-rg${commonResourceGroupSuffix}'
resource commonResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: commonResourceGroupName
  location: commonLocation
}
//The name of the storage account to avoid cycle references
var storageAccountName = replace('${commonResourceGroup.name}-str-${uniqueString(commonResourceGroup.id)}', '-', '')

//Monitoring
//----------------------------------------------------------------------------------------------------------
module logAnalyticsWorkspace './modules/logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspaceDeploy'
  scope: commonResourceGroup
  params: {
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: commonLocation
  }
}

module applicationInsights './modules/applicationInsights.bicep' = {
  name: 'applicationInsightsDeploy'
  scope: commonResourceGroup
  params: {
    location: commonLocation
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

//Primary region
//----------------------------------------------------------------------------------------------------------
var primaryResourceGroupName = '${applicationNamePrefix}-rg${primaryResourceGroupSuffix}'
resource primaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: primaryResourceGroupName
  location: primaryLocation
}

module primaryWebApp './webAppPerRegion.bicep' = {
  name: 'primaryRegionDeploy'
  scope: primaryResourceGroup
  params: {
    ghostContentFileShareName: ghostContentFileShareName
    ghostContentFilesMountPath: ghostContentFilesMountPath
    ghostHealthCheckPath: ghostHealthCheckPath
    logAnalyticsId: logAnalyticsWorkspace.outputs.id
    appServicePlanSku: appServicePlanSku
    ghostContainerName: ghostContainerName
    location: primaryLocation
    storageAccountName: storageAccountName
  }
}

//Secondary region
//----------------------------------------------------------------------------------------------------------
var secondaryResourceGroupName = '${applicationNamePrefix}-rg${secondaryResourceGroupSuffix}'
resource secondaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: secondaryResourceGroupName
  location: secondaryLocation
}

module secondaryWebApp './webAppPerRegion.bicep' = {
  name: 'secondaryRegionDeploy'
  scope: secondaryResourceGroup
  params: {
    ghostContentFileShareName: ghostContentFileShareName
    ghostContentFilesMountPath: ghostContentFilesMountPath
    ghostHealthCheckPath: ghostHealthCheckPath
    logAnalyticsId: logAnalyticsWorkspace.outputs.id
    appServicePlanSku: appServicePlanSku
    ghostContainerName: ghostContainerName
    location: secondaryLocation
    storageAccountName: storageAccountName
  }
}

//Data
//----------------------------------------------------------------------------------------------------------
module storageAccount './modules/storageAccount.bicep' = {
  name: 'storageAccountDeploy'
  scope: commonResourceGroup
  params: {
    storageAccountName: storageAccountName
    storageAccountSku: storageAccountSku
    fileShareFolderName: ghostContentFileShareName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    location: commonResourceGroup.location
    webAppPrimaryPrincipalId: primaryWebApp.outputs.webAppPrincipalId
    webAppSecondaryPrincipalId: secondaryWebApp.outputs.webAppPrincipalId
    isInitialSetup: isInitialSetup
  }
}

//webAppOutboundIpAddresses
module mySQLServer './modules/mySQLServer_single.bicep' = {
  name: 'mySQLServerDeploy'
  scope: commonResourceGroup
  params: {
    administratorLogin: databaseUser
    administratorPassword: databasePassword
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    mySQLServerSku: mySQLServerSku
    primaryLocation: primaryLocation
    secondaryLocation: secondaryLocation
    webAppPrimaryOutboundIpAddresses: primaryWebApp.outputs.webAppOutboundIpAddresses
    webAppSecondaryOutboundIpAddresses: secondaryWebApp.outputs.webAppOutboundIpAddresses
    isInitialSetup: isInitialSetup
  }
}

//FrontDoor
//----------------------------------------------------------------------------------------------------------
module frontDoor './modules/frontDoor.bicep' = {
  name: 'frontDoorDeploy'
  scope: commonResourceGroup
  params: {
    frontDoorSku: frontDoorSku
    frontDoorOrigin1HostName: primaryWebApp.outputs.webAppHostName
    frontDoorOrigin2HostName: secondaryWebApp.outputs.webAppHostName
    logAnalyticsId: logAnalyticsWorkspace.outputs.id
    healthCheckPath: ghostHealthCheckPath
  }
}

//Container Registry
//----------------------------------------------------------------------------------------------------------
module containerRegistry './modules/containerRegistry.bicep' = {
  name: 'containerRegistryDeploy'
  scope: commonResourceGroup
  params: {
    containerRegistryName: containerRegistryName
    location: commonLocation
    containerRegistrySku: containerRegistrySku
    primaryServicePrincipalId: primaryWebApp.outputs.webAppPrincipalId
    secondaryServicePrincipalId: secondaryWebApp.outputs.webAppPrincipalId
    logAnalyticsId: logAnalyticsWorkspace.outputs.id
    isInitialSetup: isInitialSetup
  }
}

//Settings
//----------------------------------------------------------------------------------------------------------
module keyVault './modules/keyVault.bicep' = {
  name: 'keyVaultDeploy'
  scope: commonResourceGroup
  params: {
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    primaryServicePrincipalId: primaryWebApp.outputs.webAppPrincipalId
    secondaryServicePrincipalId: secondaryWebApp.outputs.webAppPrincipalId
    location: commonLocation
  }
}

module keyVaultSecretMySqlPassword './modules/keyVaultSecret.bicep' = {
  name: 'keyVaultSecretMySqlPasswordDeploy'
  scope: commonResourceGroup
  params:{
    keyVaultName: keyVault.outputs.keyVaultName
    keyVaultSecretName: 'databasePassword'
    keyVaultSecretValue: databasePassword
  }
}

module primaryWebAppSettings './modules/webAppSettings.bicep' = {
  name: 'primaryWebAppSettingsDeploy'
  scope: primaryResourceGroup
  params: {
    webAppName: primaryWebApp.outputs.webAppName
    applicationInsightsConnectionString: applicationInsights.outputs.ConnectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.InstrumentationKey
    containerRegistryUrl: containerRegistry.outputs.registryUrl
    containerMountPath: ghostContentFilesMountPath
    databaseHostFQDN: mySQLServer.outputs.fullyQualifiedDomainName
    databaseUser: '${databaseUser}@${mySQLServer.outputs.mySQLName}'
    databasePasswordSecretUri: keyVaultSecretMySqlPassword.outputs.databaseSecretUri
    databaseName: databaseName
    siteUrl: frontDoor.outputs.publicUrl
  }
}

module secondaryWebAppSettings './modules/webAppSettings.bicep' = {
  name: 'secondaryWebAppSettingsDeploy'
  scope: secondaryResourceGroup
  params: {
    webAppName: secondaryWebApp.outputs.webAppName
    applicationInsightsConnectionString: applicationInsights.outputs.ConnectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.InstrumentationKey
    containerRegistryUrl: containerRegistry.outputs.registryUrl
    containerMountPath: ghostContentFilesMountPath
    databaseHostFQDN: mySQLServer.outputs.fullyQualifiedDomainName
    databaseUser: '${databaseUser}@${mySQLServer.outputs.mySQLName}'
    databasePasswordSecretUri: keyVaultSecretMySqlPassword.outputs.databaseSecretUri
    databaseName: databaseName
    siteUrl: frontDoor.outputs.publicUrl
  }
}

output publicUrl string = frontDoor.outputs.publicUrl
