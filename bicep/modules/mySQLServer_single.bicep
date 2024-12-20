@description('MySQL Server SKU')
param mySQLServerSku string = 'GP_Gen5_4'

@description('Database administrator login name')
@minLength(1)
param administratorLogin string

@description('Database administrator password')
@minLength(8)
@maxLength(128)
@secure()
param administratorPassword string

@description('Location to deploy the resources')
param primaryLocation string = resourceGroup().location

@description('Location to deploy the resources')
param secondaryLocation string

@description('Primary Web App IPs for mysql firewall')
param webAppPrimaryOutboundIpAddresses string

@description('Primary Web App IPs for mysql firewall')
param webAppSecondaryOutboundIpAddresses string

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

@description('Replicas are not idempotent, changes must be manual')
param isInitialSetup bool

var mySQLServerPrimaryName = '${resourceGroup().name}-mysql1-${uniqueString(resourceGroup().id)}'
var mySQLServerSecondaryName = '${resourceGroup().name}-mysql2-${uniqueString(resourceGroup().id)}'
var mySQLServerDiagnosticsPrimaryName = '${resourceGroup().name}-mysql-diag1-${uniqueString(resourceGroup().id)}'
var mySQLServerDiagnosticsSecondaryName = '${resourceGroup().name}-mysql-diag2-${uniqueString(resourceGroup().id)}'
var ipSetPrimaryWebApp = split(webAppPrimaryOutboundIpAddresses, ',')
var ipSetSecondaryWebApp = split(webAppSecondaryOutboundIpAddresses, ',')

//Primary mysql setup
//-----------------------------------------------------------------------------------------------
resource mySQLServerPrimary 'Microsoft.DBforMySQL/servers@2017-12-01' = {
  name: mySQLServerPrimaryName
  location: primaryLocation
  sku: {
    name: mySQLServerSku
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 4
  }
  properties: {
    createMode:'Default'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    storageProfile: {
      storageMB: 102400
      backupRetentionDays: 30
      geoRedundantBackup: 'Enabled'
      storageAutogrow: 'Enabled'
    }
    version: '5.7'
    sslEnforcement: 'Enabled'
    minimalTlsVersion: 'TLSEnforcementDisabled'
    infrastructureEncryption: 'Disabled'
    publicNetworkAccess: 'Enabled'
  }
}

resource firewallRulesPrimary1 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' = [for ip in ipSetPrimaryWebApp: {
  parent: mySQLServerPrimary
  name: 'Allow-PrimaryDb-PrimaryWebApp-${guid(ip)}'
  properties: {
    startIpAddress: '${ip}'
    endIpAddress: '${ip}'
  }
}]

resource firewallRulesPrimary2 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' = [for ip in ipSetSecondaryWebApp: {
  parent: mySQLServerPrimary
  name: 'Allow-PrimaryDb-SecondaryWebApp-${guid(ip)}'
  properties: {
    startIpAddress: '${ip}'
    endIpAddress: '${ip}'
  }
}]

//Replica mysql setup for initial deployment
//Not idepotent: https://docs.microsoft.com/en-us/azure/templates/microsoft.dbformysql/2017-12-01-preview/servers?tabs=bicep
//-----------------------------------------------------------------------------------------------
resource mySQLServerSecondary 'Microsoft.DBforMySQL/servers@2017-12-01' = if (isInitialSetup) {
  name: mySQLServerSecondaryName
  location: secondaryLocation
  sku: {
    name: mySQLServerSku
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 4
  }
  properties: {
    createMode: 'Replica'
    sourceServerId: mySQLServerPrimary.id
    storageProfile: {
      storageMB: 102400
      backupRetentionDays: 30
      geoRedundantBackup: 'Enabled'
    }
    version: '5.7'
    sslEnforcement: 'Enabled'
    minimalTlsVersion: 'TLS1_2'
    infrastructureEncryption: 'Disabled'
    publicNetworkAccess: 'Enabled'
  }
}

resource firewallRulesSecondaryInitialSetup1 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' = [for ip in ipSetPrimaryWebApp: if (isInitialSetup) {
  parent: mySQLServerSecondary
  name: 'Allow-ReplicaDb-PrimaryWebApp-${guid(ip)}'
  properties: {
    startIpAddress: '${ip}'
    endIpAddress: '${ip}'
  }
}]

resource firewallRulesSecondaryInitialSetup2 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' = [for ip in ipSetSecondaryWebApp: if (isInitialSetup) {
  parent: mySQLServerSecondary
  name: 'Allow-ReplicaDb-SecondaryWebApp-${guid(ip)}'
  properties: {
    startIpAddress: '${ip}'
    endIpAddress: '${ip}'
  }
}]

//Replica mysql setup for subsequent setups
//Not idepotent: https://docs.microsoft.com/en-us/azure/templates/microsoft.dbformysql/2017-12-01-preview/servers?tabs=bicep
//-----------------------------------------------------------------------------------------------
resource mySQLServerSecondaryExisting 'Microsoft.DBforMySQL/servers@2017-12-01' existing = if (!isInitialSetup){
  name: mySQLServerSecondaryName
}

resource firewallRulesSecondarySubsequentSetup1 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' = [for ip in ipSetPrimaryWebApp: if (!isInitialSetup) {
  parent: mySQLServerSecondary
  name: 'Allow-ExistingReplicaDb-PrimaryWebApp-${guid(ip)}'
  properties: {
    startIpAddress: '${ip}'
    endIpAddress: '${ip}'
  }
}]

resource firewallRulesSecondarySubsequentSetup2 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' = [for ip in ipSetSecondaryWebApp: if (!isInitialSetup) {
  parent: mySQLServerSecondary
  name: 'Allow-ExistingReplicaDb-SecondaryWebApp-${guid(ip)}'
  properties: {
    startIpAddress: '${ip}'
    endIpAddress: '${ip}'
  }
}]


//Alerts and diagnostics
//-----------------------------------------------------------------------------------------------
resource mySQLServerSecurityAlertsPrimary 'Microsoft.DBforMySQL/servers/securityAlertPolicies@2017-12-01' = {
  parent: mySQLServerPrimary
  name: 'Default'
  properties: {
    state: 'Enabled'
    disabledAlerts: [
      ''
    ]
    emailAddresses: [
      ''
    ]
    emailAccountAdmins: false
    retentionDays: 10
  }
}

resource mySQLServerSecurityAlertsSecondary 'Microsoft.DBforMySQL/servers/securityAlertPolicies@2017-12-01' = {
  parent: mySQLServerSecondary
  name: 'Default'
  properties: {
    state: 'Enabled'
    disabledAlerts: [
      ''
    ]
    emailAddresses: [
      ''
    ]
    emailAccountAdmins: false
    retentionDays: 10
  }
}

resource mySQLServerPrimaryDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mySQLServerPrimary
  name: mySQLServerDiagnosticsPrimaryName
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
        category: 'MySqlSlowLogs'
        enabled: true
      }
      {
        category: 'MySqlAuditLogs'
        enabled: true
      }
    ]
  }
}

resource mySQLServerSecondaryDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mySQLServerSecondary
  name: mySQLServerDiagnosticsSecondaryName
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
        category: 'MySqlSlowLogs'
        enabled: true
      }
      {
        category: 'MySqlAuditLogs'
        enabled: true
      }
    ]
  }
}

output mySQLName string = mySQLServerPrimary.name
output fullyQualifiedDomainName string = mySQLServerPrimary.properties.fullyQualifiedDomainName
