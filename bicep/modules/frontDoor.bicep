@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsId string

@description('The SKU for the frontdoor. Current setup is for premium.')
param frontDoorSku string = 'Premium_AzureFrontDoor'

@description('The host name of the primary region web app.')
param frontDoorOrigin1HostName string

@description('The host name of the primary region web app.')
param frontDoorOrigin2HostName string

@description('The path that will be probed as HTTPS GET for health.')
param healthCheckPath string

var frontDoorName = '${resourceGroup().name}-fd-${uniqueString(resourceGroup().id)}'
var frontDoorWafName = '${resourceGroup().name}-fdwaf-${uniqueString(resourceGroup().id)}'
var frontDoorWafPolicyName = replace('${resourceGroup().name}-fdwafpolicy-${uniqueString(resourceGroup().id)}', '-', '')
var frontDoorEndpointName = '${resourceGroup().name}-fdendpoint-${uniqueString(resourceGroup().id)}'
var frontDoorEndpointRouteName = '${resourceGroup().name}-fdroute-${uniqueString(resourceGroup().id)}'
var frontDoorOriginGroupName = '${resourceGroup().name}-fdog-${uniqueString(resourceGroup().id)}'
var frontDoorOriginGroupOrigin1Name = '${resourceGroup().name}-fdo1-${uniqueString(resourceGroup().id)}'
var frontDoorOriginGroupOrigin2Name = '${resourceGroup().name}-fdo2-${uniqueString(resourceGroup().id)}'
var frontDoorDiagnosticsName = '${resourceGroup().name}-fd-diag-${uniqueString(resourceGroup().id)}'

resource frontDoor 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorName
  location: 'Global'
  sku: {
    name: frontDoorSku
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

resource frontDoorWafpolicy 'Microsoft.Network/frontdoorwebapplicationfirewallpolicies@2020-11-01' = {
  name:  frontDoorWafPolicyName
  location: 'Global'
  sku: {
    name: frontDoorSku
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Detection'
      requestBodyCheck: 'Enabled'
    }
    customRules: {
      rules: []
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.0'
          ruleSetAction: 'Block'
          ruleGroupOverrides: []
          exclusions: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
          exclusions: []
        }
      ]
    }
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdendpoints@2021-06-01' = {
  parent: frontDoor
  name: frontDoorEndpointName
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/origingroups@2021-06-01' = {
  parent: frontDoor
  name: frontDoorOriginGroupName
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: healthCheckPath
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource frontDoorOrigingroupOrigin1 'Microsoft.Cdn/profiles/origingroups/origins@2021-06-01' = {
  parent: frontDoorOriginGroup
  name: frontDoorOriginGroupOrigin1Name
  properties: {
    hostName: frontDoorOrigin1HostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: frontDoorOrigin1HostName
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

resource frontDoorOriginGroupOrigin2 'Microsoft.Cdn/profiles/origingroups/origins@2021-06-01' = {
  parent: frontDoorOriginGroup
  name: frontDoorOriginGroupOrigin2Name
  properties: {
    hostName: frontDoorOrigin2HostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: frontDoorOrigin2HostName
    priority: 2
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

resource frontDoorEndpointRoute 'Microsoft.Cdn/profiles/afdendpoints/routes@2021-06-01' = {
  parent: frontDoorEndpoint
  name: frontDoorEndpointRouteName
  properties: {
    cacheConfiguration: {
      compressionSettings: {
        isCompressionEnabled: true
        contentTypesToCompress: [
          'application/eot'
          'application/font'
          'application/font-sfnt'
          'application/javascript'
          'application/json'
          'application/opentype'
          'application/otf'
          'application/pkcs7-mime'
          'application/truetype'
          'application/ttf'
          'application/vnd.ms-fontobject'
          'application/xhtml+xml'
          'application/xml'
          'application/xml+rss'
          'application/x-font-opentype'
          'application/x-font-truetype'
          'application/x-font-ttf'
          'application/x-httpd-cgi'
          'application/x-javascript'
          'application/x-mpegurl'
          'application/x-opentype'
          'application/x-otf'
          'application/x-perl'
          'application/x-ttf'
          'font/eot'
          'font/ttf'
          'font/otf'
          'font/opentype'
          'image/svg+xml'
          'text/css'
          'text/csv'
          'text/html'
          'text/javascript'
          'text/js'
          'text/plain'
          'text/richtext'
          'text/tab-separated-values'
          'text/xml'
          'text/x-script'
          'text/x-component'
          'text/x-java-source'
        ]
      }
      queryStringCachingBehavior: 'UseQueryString'
    }
    customDomains: []
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

resource frontDoorWaf 'Microsoft.Cdn/profiles/securitypolicies@2021-06-01' = {
  parent: frontDoor
  name: frontDoorWafName
  properties: {
    parameters: {
      wafPolicy: {
        id: frontDoorWafpolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
      type: 'WebApplicationFirewall'
    }
  }
}

resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontDoor
  name: frontDoorDiagnosticsName
  properties: {
    workspaceId: logAnalyticsId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'FrontdoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontdoorWebApplicationFirewallLog'
        enabled: true
      }
    ]
  }
}

output publicUrl string = 'https://${frontDoorName}.azurefd.net'
