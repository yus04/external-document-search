targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param principalType string = ''

param appServicePlanName string = ''
param backendServiceName string = ''

param resourceGroupName string = ''

param applicationInsightsName string = ''
param workspaceName string = ''

param openAiServiceName string = ''
param openAiResourceGroupName string = ''
param openAiResourceGroupLocation string = location

param openAiSkuName string = 'S0'

param openAiGpt35TurboDeploymentName string = 'gpt-35-turbo-deploy'
param openAiGpt35Turbo16kDeploymentName string = 'gpt-35-turbo-16k-deploy'
param openAiGpt4DeploymentName string = ''
param openAiGpt432kDeploymentName string = ''
param openAiApiVersion string = '2023-05-15'

param cosmosDbDatabaseName string = 'ChatHistory'
param cosmosDbContainerName string = 'Prompts'

param cosmosDbResourceGroupName string = ''

// Azure ポータルから取得した Bing Search v7 の
// サブスクリプションキーを入力
param bingSearchSubscriptionKey string = '5009c6ee46b84c8a9438145e53455449'

param bingSearchUrl string = 'https://api.bing.microsoft.com/v7.0/search'

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Use Application Insights for monitoring and performance tracing')
param useApplicationInsights bool = true

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

resource openAiResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(openAiResourceGroupName)) {
  name: !empty(openAiResourceGroupName) ? openAiResourceGroupName : resourceGroup.name
}

resource cosmosDbResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(cosmosDbResourceGroupName)) {
  name: !empty(cosmosDbResourceGroupName) ? cosmosDbResourceGroupName : resourceGroup.name
}


module cosmosDb 'core/db/cosmosdb.bicep' = {
  name: 'cosmosdb'
  scope: cosmosDbResourceGroup
  params: {
    name: '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'cosmosdb' })
    cosmosDbDatabaseName: cosmosDbDatabaseName
    cosmosDbContainerName: cosmosDbContainerName
    publicNetworkAccess: 'Enabled'
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'S1'
      capacity: 1
    }
    kind: 'linux'
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = if (useApplicationInsights) {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    workspaceName: !empty(workspaceName) ? workspaceName : '${abbrs.insightsComponents}${resourceToken}-workspace'
    location: location
    tags: tags
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
  }
}

// The application frontend
module backend 'core/host/appservice.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    name: !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesAppService}backend-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'backend' })
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    scmDoBuildDuringDeployment: true
    managedIdentity: true
    applicationInsightsName: useApplicationInsights ? monitoring.outputs.applicationInsightsName : ''
    virtualNetworkSubnetId: ''
    appSettings: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: useApplicationInsights ? monitoring.outputs.applicationInsightsConnectionString : ''
      AZURE_OPENAI_SERVICE: openAi.outputs.name
      AZURE_OPENAI_GPT_35_TURBO_DEPLOYMENT: openAiGpt35TurboDeploymentName
      AZURE_OPENAI_GPT_35_TURBO_16K_DEPLOYMENT: openAiGpt35Turbo16kDeploymentName
      AZURE_OPENAI_GPT_4_DEPLOYMENT: ''
      AZURE_OPENAI_GPT_4_32K_DEPLOYMENT: ''
      AZURE_OPENAI_API_VERSION: '2023-05-15'
      AZURE_COSMOSDB_CONTAINER: cosmosDbContainerName
      AZURE_COSMOSDB_DATABASE: cosmosDbDatabaseName
      AZURE_COSMOSDB_ENDPOINT: cosmosDb.outputs.endpoint
      BING_SEARCH_SUBSCRIPTION_KEY: bingSearchSubscriptionKey
      BING_SEARCH_URL: bingSearchUrl
    }
  }
}

module openAi 'core/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: openAiResourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiResourceGroupLocation
    tags: tags
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: openAiGpt35TurboDeploymentName
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo'
          version: '0613'
        }
        sku: {
          name: 'Standard'
          capacity: 60
        }
      }
      {
        name: openAiGpt35Turbo16kDeploymentName
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo-16k'
          version: '0613'
        }
        sku: {
          name: 'Standard'
          capacity: 60
        }
      }
    ]
    publicNetworkAccess: 'Enabled'
  }
}

// ================================================================================================
// USER ROLES
// ================================================================================================
module openAiRoleUser 'core/security/role.bicep' = {
  scope: openAiResourceGroup
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: !empty(principalType) ? principalType : 'User'
  }
}

module cosmosDbRoleUser 'core/security/role.bicep' = {
  scope: cosmosDbResourceGroup
  name: 'cosmosdb-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5bd9cd88-fe45-4216-938b-f97437e15450'
    principalType: !empty(principalType) ? principalType : 'User'
  }
}

// ================================================================================================
// SYSTEM IDENTITIES
// ================================================================================================
module openAiRoleBackend 'core/security/role.bicep' = {
  scope: openAiResourceGroup
  name: 'openai-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
}

module cosmosDbRoleBackend 'core/security/role.bicep' = {
  scope: cosmosDbResourceGroup
  name: 'cosmosdb-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: '5bd9cd88-fe45-4216-938b-f97437e15450'
    principalType: 'ServicePrincipal'
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name

output AZURE_OPENAI_SERVICE string = openAi.outputs.name
output AZURE_OPENAI_RESOURCE_GROUP string = openAiResourceGroup.name
output AZURE_OPENAI_GPT_35_TURBO_DEPLOYMENT string = openAiGpt35TurboDeploymentName
output AZURE_OPENAI_GPT_35_TURBO_16K_DEPLOYMENT string = openAiGpt35Turbo16kDeploymentName
output AZURE_OPENAI_GPT_4_DEPLOYMENT string = openAiGpt4DeploymentName
output AZURE_OPENAI_GPT_4_32K_DEPLOYMENT string = openAiGpt432kDeploymentName
output AZURE_OPENAI_API_VERSION string = openAiApiVersion

output AZURE_COSMOSDB_ENDPOINT string = cosmosDb.outputs.endpoint
output AZURE_COSMOSDB_DATABASE string = cosmosDb.outputs.databaseName
output AZURE_COSMOSDB_CONTAINER string = cosmosDb.outputs.containerName

output AZURE_COSMOSDB_ACCOUNT string = cosmosDb.outputs.accountName
output AZURE_COSMOSDB_RESOURCE_GROUP string = cosmosDbResourceGroup.name

output BING_SEARCH_SUBSCRIPTION_KEY string = bingSearchSubscriptionKey
output BING_SEARCH_URL string = bingSearchUrl

output BACKEND_IDENTITY_PRINCIPAL_ID string = backend.outputs.identityPrincipalId
output BACKEND_URI string = backend.outputs.uri
