@description('Secret name to store')
@minLength(1)
@maxLength(127)
param keyVaultSecretName string

@description('Secret value to store')
@secure()
param keyVaultSecretValue string

@description('The keyVault name for the secret to be stored')
param keyVaultName string


resource existingKeyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' existing = {
  name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: existingKeyVault
  name: keyVaultSecretName
  properties: {
    value: keyVaultSecretValue
  }
}

output databaseSecretUri string = keyVaultSecret.properties.secretUri
