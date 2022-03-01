// TODO: Structure Bicep code for collaboration i.e. by adding comments and metadata (See: https://docs.microsoft.com/en-us/learn/modules/structure-bicep-code-collaboration/)

// Parameters
param acrName string = 'acr${uniqueString(resourceGroup().id)}'

param aksName string = 'aks${uniqueString(resourceGroup().id)}'
param aksDnsServiceIP string = '10.0.0.10'
param aksDockerBridgeCidr string = '172.17.0.1/16'
param aksKubernetesVersion string = '1.21.7'
param aksServiceCidr string = '10.0.0.0/16'

param kvName string = 'kv${uniqueString(resourceGroup().id)}'

param location string = resourceGroup().location

param sbName string = 'sb${uniqueString(resourceGroup().id)}'

param srcName string = 'src${uniqueString(resourceGroup().id)}'
param srcIdentityName string = 'src${uniqueString(resourceGroup().id)}'

param stAccName string = 'st${uniqueString(resourceGroup().id)}'
param stTableName string = 'daprStore'

param vnetName string = 'vnet${uniqueString(resourceGroup().id)}'
param vnetAddressPrefixes array = [
  '10.0.0.0/8'
]
param vnetSubnets array = [
  {
    name: 'default'
    properties: {
      addressPrefix: '10.240.0.0/16'
    }
  }
]

// Variables
var acrPullRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'

var aksIdentityObjectId = aks.properties.identityProfile.kubeletidentity.objectId

var networkContributorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'

var tenantId = subscription().tenantId

// Resources
resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource kv 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: kvName
  location: location
  properties: {
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: aksIdentityObjectId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          certificates: []
          keys: []
        }
      }
    ]
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: false
  }
}

resource kvAddStAccKey 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: '${kv.name}/StAccKey'
  properties: {
    value: '${listKeys(stAcc.id, stAcc.apiVersion).keys[0].value}'
  }
}

resource sbAddSbConnStr 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: '${kv.name}/SbConnStr'
  properties: {
    value: '${listKeys('${sb.id}/AuthorizationRules/RootManageSharedAccessKey', sb.apiVersion).primaryConnectionString}'
  }
}

resource stAcc 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: stAccName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    defaultToOAuthAuthentication: false
    allowCrossTenantReplication: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        table: {
          keyType: 'Account'
          enabled: true
        }
        queue: {
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
    accessTier: 'Hot'
  }
}

resource stTableSvc 'Microsoft.Storage/storageAccounts/tableServices@2021-08-01' = {
  parent: stAcc
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource stTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-08-01' = {
  parent: stTableSvc
  name: stTableName
}

resource sb 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: sbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    zoneRedundant: false
  }
}

// Create subnets by using subnets property, since their definition as child resources can cause issues in subsequent deployments.
// (See: https://docs.microsoft.com/en-nz/azure/azure-resource-manager/bicep/scenarios-virtual-networks#virtual-networks-and-subnets)
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
    subnets: vnetSubnets
  }
}

// Refer to previously created subnet.
resource aksVnetSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${vnet.name}/${vnetSubnets[0].name}'
}

resource aks 'Microsoft.ContainerService/managedClusters@2021-07-01' = {
  location: location
  name: aksName
  properties: {
    kubernetesVersion: aksKubernetesVersion
    enableRBAC: true
    dnsPrefix: aksName
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: 0
        count: 3
        enableAutoScaling: false
        vmSize: 'Standard_B4ms'
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        maxPods: 110
        availabilityZones: []
        enableNodePublicIP: false
        vnetSubnetID: aksVnetSubnet.id
      }
    ]
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: 'azure'
      serviceCidr: aksServiceCidr
      dnsServiceIP: aksDnsServiceIP
      dockerBridgeCidr: aksDockerBridgeCidr
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    addonProfiles: {
      httpApplicationRouting: {
        enabled: true
      }
      azurepolicy: {
        enabled: false
      }
      azureKeyvaultSecretsProvider: {
        enabled: false
      }
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource aksAssignNetworkContributorRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, aksVnetSubnet.id, aks.id, networkContributorRole)
  scope: aksVnetSubnet
  properties: {
    roleDefinitionId: networkContributorRole
    principalId: aksIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

resource aksAssignAcrPull 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, acr.id, aks.id, acrPullRole)
  scope: acr
  properties: {
    roleDefinitionId: acrPullRole
    principalId: aksIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

// Modules
module daprModule 'modules/dapr.bicep' = {
  scope: resourceGroup()
  name: 'dapr'
  params: {
    aksName: aks.name
    daprVersion: '1.6'
    location: location
    rgName: resourceGroup().name
    srcIdentityName: srcIdentityName
    srcName: srcName
  }
}

// Outputs
output acrName string = acr.name

output acrLoginServer string = acr.properties.loginServer

output aksName string = aks.name

output aksHttpAppRoutingZoneName string = aks.properties.addonProfiles.httpApplicationRouting.config.HTTPApplicationRoutingZoneName

output kvName string = kv.name

output stAccName string = stAcc.name
