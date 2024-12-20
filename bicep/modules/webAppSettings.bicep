param webAppName string

param applicationInsightsInstrumentationKey string

param applicationInsightsConnectionString string

@description('MySQL server hostname')
param databaseHostFQDN string

@description('Ghost datbase name')
param databaseName string

@description('Ghost database user name')
param databaseUser string

@description('Ghost database user password')
param databasePasswordSecretUri string

@description('Website URL to autogenerate links by Ghost')
param siteUrl string

@description('Mount path for Ghost content files')
param containerMountPath string

@description('Container registry to pull Ghost docker image')
param containerRegistryUrl string = 'https://customghost.azurecr.io'

resource existingWebApp 'Microsoft.Web/sites@2020-09-01' existing = {
  name: webAppName
}

resource webAppSettings 'Microsoft.Web/sites/config@2021-01-15' = {
  parent: existingWebApp
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsightsInstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsightsConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    XDT_MicrosoftApplicationInsights_Mode: 'default'
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
    DOCKER_REGISTRY_SERVER_URL: containerRegistryUrl
    DOCKER_ENABLE_CI: 'true'
    // Ghost-specific settings
    NODE_ENV: 'production'
    GHOST_CONTENT: containerMountPath
    paths__contentPath: containerMountPath
    privacy_useUpdateCheck: 'false'
    url: siteUrl
    database__client: 'mysql'
    database__connection__host: databaseHostFQDN
    database__connection__user: databaseUser
    database__connection__password: '@Microsoft.KeyVault(SecretUri=${databasePasswordSecretUri})'
    database__connection__database: databaseName
    database__connection__ssl: 'true'
    database__connection__ssl_minVersion: 'TLSv1.2'
  }
}
