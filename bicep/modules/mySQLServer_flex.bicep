
@description('MySQL Server SKU')
param mySQLServerSku string = 'Standard_B1ms'

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


@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

var mySQLServerName = '${resourceGroup().name}-mysql-${uniqueString(resourceGroup().id)}'
var mySQLFirewallRulesName = '${resourceGroup().name}-mysql-firewall-${uniqueString(resourceGroup().id)}'
var mySQLServerDiagnosticsName = '${resourceGroup().name}-mysql-diag-${uniqueString(resourceGroup().id)}'

resource mySQLServer 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = {
  name: mySQLServerName
  location: primaryLocation
  sku: {
    name: mySQLServerSku
    tier: 'GeneralPurpose'
  }
  properties: {
    createMode: 'Default'
    version: '5.7'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    backup: {
      backupRetentionDays: 30
      geoRedundantBackup: 'Enabled'
    }
    availabilityZone: primaryLocation
    highAvailability: {
      mode: 'ZoneRedundant'
      standbyAvailabilityZone: secondaryLocation
    }
  }
}

resource firewallRulesPrimary 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2021-05-01' = {
  parent: mySQLServer
  name: mySQLFirewallRulesName
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource firewallRulesSecondary 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2021-05-01' = {
  parent: mySQLServer
  name: mySQLFirewallRulesName
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}


resource mySQLServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mySQLServer
  name: mySQLServerDiagnosticsName
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

output mySQLName string = mySQLServer.name
output fullyQualifiedDomainName string = mySQLServer.properties.fullyQualifiedDomainName
