@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
])
@description('Storage Account SKU Code')
param storageAccountSku string = 'Standard_GRS'

@description('File share to store Ghost content files')
param fileShareFolderName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

@description('The Service Principal ID of the primary App Service')
param webAppPrimaryPrincipalId string

@description('The Service Principal ID of the secondary App Service')
param webAppSecondaryPrincipalId string

@description('BackupInstances and Roles are not idempotent, changes must be manual')
param isInitialSetup bool

@description('The name of the storage account')
param storageAccountName string

var storageAccountDiagnosticsName = '${resourceGroup().name}-str-dia-${uniqueString(resourceGroup().id)}'
var fileServicesDiagnosticsName = '${resourceGroup().name}-afs-dia-${uniqueString(resourceGroup().id)}'
var backUpVaultName = replace('${resourceGroup().name}-abu-${uniqueString(resourceGroup().id)}', '-', '')
var backUpVaultPolicyName = replace('${resourceGroup().name}-abu-plc-${uniqueString(resourceGroup().id)}', '-', '')

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: storageAccountSku
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2021-04-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource storageAccountDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: storageAccountDiagnosticsName
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource fileServicesDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: fileServices
  name: fileServicesDiagnosticsName
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  parent: fileServices
  name: fileShareFolderName
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 5120
  }
}

resource backUpVault 'Microsoft.DataProtection/BackupVaults@2022-03-01' = {
  name: backUpVaultName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    storageSettings: [
      {
        datastoreType: 'VaultStore'
        type: 'GeoRedundant'
      }
    ]
  }
}

resource backUpVaultPolicy 'Microsoft.DataProtection/BackupVaults/backupPolicies@2022-03-01' = {
  parent: backUpVault
  name: backUpVaultPolicyName
  properties: {
    policyRules: [
      {
        lifecycles: [
          {
            deleteAfter: {
              objectType: 'AbsoluteDeleteOption'
              duration: 'P30D'
            }
            targetDataStoreCopySettings: []
            sourceDataStore: {
              dataStoreType: 'OperationalStore'
              objectType: 'DataStoreInfoBase'
            }
          }
        ]
        isDefault: true
        name: 'Default'
        objectType: 'AzureRetentionRule'
      }
    ]
    datasourceTypes: [
      'Microsoft.Storage/storageAccounts/blobServices'
    ]
    objectType: 'BackupPolicy'

  }
}

resource backUpVaultInstance 'Microsoft.DataProtection/backupVaults/backupInstances@2022-03-01' = if (isInitialSetup) {
  parent: backUpVault
  name: storageAccountName //weirdly enough, this is transformed to format('{0}/{1}', variables('backUpVaultName'), variables('storageAccountName'))
  properties: {
    objectType: 'BackupInstance'
    dataSourceInfo: {
      resourceID: storageAccount.id
      resourceUri: storageAccount.id
      datasourceType: 'Microsoft.Storage/storageAccounts/blobServices'
      resourceName: storageAccount.name
      resourceType: 'Microsoft.Storage/storageAccounts'
      resourceLocation: location
      objectType: 'Datasource'
    }
    policyInfo: {
      policyId: backUpVaultPolicy.id
    }
  }
}

//https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-file-data-smb-share-contributor
resource roleAssignmentsPrimaryWebApp 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (isInitialSetup) {
  scope: storageAccount
  name: guid(storageAccount.id, webAppPrimaryPrincipalId, '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb') 
    principalId: webAppPrimaryPrincipalId
    principalType: 'ServicePrincipal'
  }
}

//https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-file-data-smb-share-contributor
resource roleAssignmentSecondaryWebApp 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (isInitialSetup) {
  scope: storageAccount
  name: guid(storageAccount.id, webAppSecondaryPrincipalId, '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb') 
    principalId: webAppSecondaryPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output id string = storageAccount.id
output name string = storageAccount.name
output fileShareFullName string = fileShare.name

//output accessKey string = listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value

