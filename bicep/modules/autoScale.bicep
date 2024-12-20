@description('The minimum capacity.  Autoscale engine will ensure the instance count is at least this value.')
param minimumCapacity int = 3

@description('The maximum capacity.  Autoscale engine will ensure the instance count is not greater than this value.')
param maximumCapacity int = 6

@description('The default capacity.  Autoscale engine will preventively set the instance count to be this value if it can not find any metric data.')
param defaultCapacity int = 3

@description('The metric name.')
param metricName string = 'CpuPercentage'

@description('The metric upper threshold.  If the metric value is above this threshold then autoscale engine will initiate scale out action.')
param metricThresholdToScaleOut int = 85

@description('The metric lower threshold.  If the metric value is below this threshold then autoscale engine will initiate scale in action.')
param metricThresholdToScaleIn int = 60

@description('A boolean to indicate whether the autoscale policy is enabled or disabled.')
param autoscaleEnabled bool = true

@description('Location for resources.')
param location string = resourceGroup().location

@description('Location for resources.')
param appServicePlanNameId string

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

var appAutoScaleSettingsName = '${resourceGroup().name}-ass-${uniqueString(resourceGroup().id)}'
var appAutoScaleSettingsDiagnosticsName = '${resourceGroup().name}-ass-${uniqueString(resourceGroup().id)}'
var appAutoScaleProfileName = '${resourceGroup().name}-dasp-${uniqueString(resourceGroup().id)}'

resource appAutoScaleSettings 'Microsoft.Insights/autoscalesettings@2014-04-01' = {
  name: appAutoScaleSettingsName
  location: location
  properties: {
    profiles: [
      {
        name: appAutoScaleProfileName
        capacity: {
          minimum: string(minimumCapacity)
          maximum: string(maximumCapacity)
          default: string(defaultCapacity)
        }
        rules: [
          {
            metricTrigger: {
              metricName: metricName
              metricResourceUri: appServicePlanNameId
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: metricThresholdToScaleOut
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricName: metricName
              metricResourceUri: appServicePlanNameId
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: int(metricThresholdToScaleIn)
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
    enabled: autoscaleEnabled
    targetResourceUri: appServicePlanNameId
  }
}

resource appAutoScaleSettingsDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appAutoScaleSettings
  name: appAutoScaleSettingsDiagnosticsName
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [] //todo: log
  }
}
