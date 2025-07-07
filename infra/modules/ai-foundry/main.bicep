metadata name = 'AI Services and Project Module'
metadata description = 'This module creates an AI Services resource and an AI Foundry project within it. It supports private networking, OpenAI deployments, and role assignments.'

@description('Required. Name of the Cognitive Services resource. Must be unique in the resource group.')
param name string

@description('Optional. The location of the Cognitive Services resource.')
param location string // this should be passed 

@description('Optional. Kind of the Cognitive Services account. Use \'Get-AzCognitiveServicesAccountSku\' to determine a valid combinations of \'kind\' and \'SKU\' for your Azure region.')
@allowed([
  'AIServices'
  'AnomalyDetector'
  'CognitiveServices'
  'ComputerVision'
  'ContentModerator'
  'ContentSafety'
  'ConversationalLanguageUnderstanding'
  'CustomVision.Prediction'
  'CustomVision.Training'
  'Face'
  'FormRecognizer'
  'HealthInsights'
  'ImmersiveReader'
  'Internal.AllInOne'
  'LUIS'
  'LUIS.Authoring'
  'LanguageAuthoring'
  'MetricsAdvisor'
  'OpenAI'
  'Personalizer'
  'QnAMaker.v2'
  'SpeechServices'
  'TextAnalytics'
  'TextTranslation'
])
param kind string = 'AIServices'

@description('Optional. The SKU of the Cognitive Services account. Use \'Get-AzCognitiveServicesAccountSku\' to determine a valid combinations of \'kind\' and \'SKU\' for your Azure region.')
@allowed([
  'S'
  'S0'
  'S1'
  'S2'
  'S3'
  'S4'
  'S5'
  'S6'
  'S7'
  'S8'
])
param sku string = 'S0'

@description('Required. The name of the AI Foundry project to create.')
param projectName string

@description('Optional. The description of the AI Foundry project to create.')
param projectDescription string = projectName

@description('Optional. The resource ID of the Log Analytics workspace to use for diagnostic settings.')
param logAnalyticsWorkspaceResourceId string?

@description('Optional. Use this parameter to use an existing AI project resource ID')
param azureExistingAIProjectResourceId string = ''

import { diagnosticSettingFullType } from 'br/public:avm/utl/types/avm-common-types:0.5.1'
@description('Optional. The diagnostic settings of the service.')
param diagnosticSettings diagnosticSettingFullType[]?

import { deploymentType } from 'br/public:avm/res/cognitive-services/account:0.10.2'
@description('Optional. Specifies the OpenAI deployments to create.')
param deployments deploymentType[] = []

import { roleAssignmentType } from 'br/public:avm/utl/types/avm-common-types:0.5.1'
@description('Optional. Array of role assignments to create.')
param roleAssignments roleAssignmentType[] = []

import { privateEndpointSingleServiceType } from 'br/public:avm/utl/types/avm-common-types:0.5.1'
@description('Optional. Configuration details for private endpoints. For security reasons, it is recommended to use private endpoints whenever possible.')
param privateEndpoints privateEndpointSingleServiceType[]?

@description('Optional. Key vault reference and secret settings for the module\'s secrets export.')
param secretsExportConfiguration secretsExportConfigurationType?

@description('Optional. Values to establish private networking for the AI Services resource.')
param privateNetworking aiServicesPrivateNetworkingType?

@description('Optional. A collection of rules governing the accessibility from specific network locations.')
param networkAcls object?

@description('Optional. The network injection subnet resource Id for the Cognitive Services account. This allows to use the AI Services account with a virtual network.')
param networkInjectionSubnetResourceId string?

@description('Optional. The flag to enable dynamic throttling.')
param dynamicThrottlingEnabled bool = false

@secure()
@description('Optional. Resource migration token.')
param migrationToken string?

@description('Optional. List of allowed FQDN.')
param allowedFqdnList array?

@description('Optional. The API properties for special APIs.')
param apiProperties object?

@description('Optional. Restore a soft-deleted cognitive service at deployment time. Will fail if no such soft-deleted resource exists.')
param restore bool = false

@description('Optional. Restrict outbound network access.')
param restrictOutboundNetworkAccess bool = true

@description('Optional. The storage accounts for this resource.')
param userOwnedStorage array?

@description('Optional. Tags to be applied to the resources.')
param tags object = {}

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true


// ================ //
// AI Services      //
// ================ //



module cognitiveServicesPrivateDnsZone '../privateDnsZone.bicep' = if (!useExistingAIServices && privateNetworking != null && empty(privateNetworking.?cogServicesPrivateDnsZoneResourceId)) {
  name: take('${name}-cognitiveservices-pdns-deployment', 64)
  params: {
    name: 'privatelink.cognitiveservices.${toLower(environment().name) == 'azureusgovernment' ? 'azure.us' : 'azure.com'}'
    virtualNetworkResourceId: privateNetworking.?virtualNetworkResourceId ?? ''
    tags: tags
  }
}

module openAiPrivateDnsZone '../privateDnsZone.bicep' = if (!useExistingAIServices && privateNetworking != null && empty(privateNetworking.?openAIPrivateDnsZoneResourceId)) {
  name: take('${name}-openai-pdns-deployment', 64)
  params: {
    name: 'privatelink.openai.${toLower(environment().name) == 'azureusgovernment' ? 'azure.us' : 'azure.com'}'
    virtualNetworkResourceId: privateNetworking.?virtualNetworkResourceId ?? ''
    tags: tags
  }
}

module aiServicesPrivateDnsZone '../privateDnsZone.bicep' = if (!useExistingAIServices && privateNetworking != null && empty(privateNetworking.?aiServicesPrivateDnsZoneResourceId)) {
  name: take('${name}-ai-services-pdns-deployment', 64)
  params: {
    name: 'privatelink.services.ai.${toLower(environment().name) == 'azureusgovernment' ? 'azure.us' : 'azure.com'}'
    virtualNetworkResourceId: privateNetworking.?virtualNetworkResourceId ?? ''
    tags: tags
  }
}

var cogServicesPrivateDnsZoneResourceId = privateNetworking != null
  ? (empty(privateNetworking.?cogServicesPrivateDnsZoneResourceId)
      ? cognitiveServicesPrivateDnsZone.outputs.resourceId ?? ''
      : privateNetworking.?cogServicesPrivateDnsZoneResourceId)
  : ''
var openAIPrivateDnsZoneResourceId = privateNetworking != null
  ? (empty(privateNetworking.?openAIPrivateDnsZoneResourceId)
      ? openAiPrivateDnsZone.outputs.resourceId ?? ''
      : privateNetworking.?openAIPrivateDnsZoneResourceId)
  : ''

var aiServicesPrivateDnsZoneResourceId = privateNetworking != null
  ? (empty(privateNetworking.?aiServicesPrivateDnsZoneResourceId)
      ? aiServicesPrivateDnsZone.outputs.resourceId ?? ''
      : privateNetworking.?aiServicesPrivateDnsZoneResourceId)
  : ''


// Extract components from existing AI Services Resource ID if provided
var useExistingAIServices = !empty(azureExistingAIProjectResourceId)
var managedIdentities = {
      systemAssigned: true
    }
var formattedUserAssignedIdentities = reduce(
  map((managedIdentities.?userAssignedResourceIds ?? []), (id) => { '${id}': {} }),
  {},
  (cur, next) => union(cur, next)
) // Converts the flat array to an object like { '${id1}': {}, '${id2}': {} }
var identity = !empty(managedIdentities)
  ? {
      type: (managedIdentities.?systemAssigned ?? false)
        ? (!empty(managedIdentities.?userAssignedResourceIds ?? {}) ? 'SystemAssigned, UserAssigned' : 'SystemAssigned')
        : (!empty(managedIdentities.?userAssignedResourceIds ?? {}) ? 'UserAssigned' : null)
      userAssignedIdentities: !empty(formattedUserAssignedIdentities) ? formattedUserAssignedIdentities : null
    }
  : null

//create a new Cognitive Services resource here and then just send to create its dependencies

resource newCognitiveService 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = if(!useExistingAIServices) {
  name: take('${name}-aiservices-deployment', 64)
  kind: kind
  identity: identity
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    customSubDomainName: name
    allowProjectManagement: true
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: privateNetworking != null ? 'Disabled' : 'Enabled'
    allowedFqdnList: allowedFqdnList
    apiProperties: apiProperties
    disableLocalAuth: false
    #disable-next-line BCP036
    networkInjections: networkInjectionSubnetResourceId != null
      ? [
          {
            scenario: 'agent'
            subnetArmId: networkInjectionSubnetResourceId
            useMicrosoftManagedNetwork: false
          }
        ]
      : null
    // true is not supported today
    encryption: null // Customer managed key encryption is used, but the property is required.
    migrationToken: migrationToken
    restore: restore
    restrictOutboundNetworkAccess: restrictOutboundNetworkAccess
    userOwnedStorage: userOwnedStorage
    dynamicThrottlingEnabled: dynamicThrottlingEnabled
  }
}

var existingCognitiveServiceDetails = split(azureExistingAIProjectResourceId, '/')

// Reference to existing AI Services in different resource group
resource existingCognitiveService 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = if (useExistingAIServices) {
  name: existingCognitiveServiceDetails[8]
  scope: resourceGroup(existingCognitiveServiceDetails[2], existingCognitiveServiceDetails[4])
}

module cognitive_service_dependencies 'ai-services.bicep' = if(!useExistingAIServices) {
  params: {
    projectName: projectName
    projectDescription: projectDescription
    name:  newCognitiveService.name
    azureExistingAIProjectResourceId: azureExistingAIProjectResourceId
    location: location
    deployments: deployments
    diagnosticSettings: diagnosticSettings
    privateEndpoints: privateEndpoints
    roleAssignments: roleAssignments
    secretsExportConfiguration: secretsExportConfiguration
    sku: sku
    tags: tags
  }
}

module existing_cognitive_service_dependencies 'ai-services.bicep' = if(useExistingAIServices) {
  params: {
    projectName: projectName
    projectDescription: projectDescription
    name:  existingCognitiveService.name 
    azureExistingAIProjectResourceId: azureExistingAIProjectResourceId
    location: location
    deployments: deployments
    diagnosticSettings: diagnosticSettings
    privateEndpoints: privateEndpoints
    roleAssignments: roleAssignments
    secretsExportConfiguration: secretsExportConfiguration
    sku: sku
    tags: tags
  }
  scope: resourceGroup(existingCognitiveServiceDetails[2], existingCognitiveServiceDetails[4])
}

@description('The resource group the resources were deployed into.')
output resourceGroupName string = useExistingAIServices ? existingCognitiveServiceDetails[4] : resourceGroup().name

@description('Name of the Cognitive Services resource.')
output name string = useExistingAIServices ? existingCognitiveServiceDetails[8] : newCognitiveService.name

@description('Resource ID of the Cognitive Services resource.')
output resourceId string = useExistingAIServices ? azureExistingAIProjectResourceId : newCognitiveService.id

@description('Principal ID of the system assigned managed identity for the Cognitive Services resource. This is only available if the resource has a system assigned managed identity.')
output systemAssignedMIPrincipalId string? = useExistingAIServices ? existingCognitiveService.identity.principalId : newCognitiveService.identity.principalId

@description('The endpoint of the Cognitive Services resource.')
output endpoint string = useExistingAIServices ? existingCognitiveService.properties.endpoint : newCognitiveService.properties.endpoint


import { aiProjectOutputType } from './project.bicep'
output aiProjectInfo aiProjectOutputType = useExistingAIServices ? existing_cognitive_service_dependencies.outputs.aiProjectInfo : cognitive_service_dependencies.outputs.aiProjectInfo

@export()
@description('A custom AVM-aligned type for a role assignment for AI Services and Project.')
type aiServicesRoleAssignmentType = {
  @description('Optional. The name (as GUID) of the role assignment. If not provided, a GUID will be generated.')
  name: string?

  @description('Required. The role to assign. You can provide either the role definition GUID or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.')
  roleDefinitionId: string

  @description('Required. The principal ID of the principal (user/group/identity) to assign the role to.')
  principalId: string

  @description('Optional. The principal type of the assigned principal ID.')
  principalType: ('ServicePrincipal' | 'Group' | 'User' | 'ForeignGroup' | 'Device')?
}

@export()
@description('The type of the secrets exported to the provided Key Vault.')
type secretsExportConfigurationType = {
  @description('Required. The key vault name where to store the keys and connection strings generated by the modules.')
  keyVaultResourceId: string

  @description('Optional. The name for the accessKey1 secret to create.')
  accessKey1Name: string?

  @description('Optional. The name for the accessKey2 secret to create.')
  accessKey2Name: string?
}

@export()
@description('Values to establish private networking for resources that support createing private endpoints.')
type aiServicesPrivateNetworkingType = {
  @description('Required. The Resource ID of the virtual network.')
  virtualNetworkResourceId: string

  @description('Required. The Resource ID of the subnet to establish the Private Endpoint(s).')
  subnetResourceId: string

  @description('Optional. The Resource ID of an existing "cognitiveservices" Private DNS Zone Resource to link to the virtual network. If not provided, a new "cognitiveservices" Private DNS Zone(s) will be created.')
  cogServicesPrivateDnsZoneResourceId: string?

  @description('Optional. The Resource ID of an existing "openai" Private DNS Zone Resource to link to the virtual network. If not provided, a new "openai" Private DNS Zone(s) will be created.')
  openAIPrivateDnsZoneResourceId: string?
  
  @description('Optional. The Resource ID of an existing "services.ai" Private DNS Zone Resource to link to the virtual network. If not provided, a new "services.ai" Private DNS Zone(s) will be created.')
  aiServicesPrivateDnsZoneResourceId: string?
}
