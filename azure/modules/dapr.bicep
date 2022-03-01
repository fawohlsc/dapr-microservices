// TODO: Structure Bicep code for collaboration i.e. by adding comments and metadata (See: https://docs.microsoft.com/en-us/learn/modules/structure-bicep-code-collaboration/)

// Parameters
param aksName string

param daprVersion string

param location string

param srcIdentityName string
param srcName string

param rgName string

// Variables
var contributorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

// Resources
resource srcIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: srcIdentityName
  location: location
}

resource srcIdentityAssignConributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, resourceGroup().id, srcIdentity.id, contributorRole)
  properties: {
    roleDefinitionId: contributorRole
    principalId: srcIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource src 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: srcName
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${srcIdentity.id}': {}
    }
  }
  properties: {
    environmentVariables: [
      {
        name: 'RG_NAME'
        value: rgName
      }
      {
        name: 'AKS_NAME'
        value: aksName
      }
      {
        name: 'DAPR_VERSION'
        value: daprVersion
      }
    ]
    azCliVersion: '2.33.0'
    scriptContent: '''
      # Get kubernetes credentials
      az aks get-credentials -n $AKS_NAME -g $RG_NAME

      # Install helm
      curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
      chmod 700 get_helm.sh
      ./get_helm.sh

      # Add helm repo
      helm repo add dapr https://dapr.github.io/helm-charts/
      helm repo update

      # Install dapr
      # helm upgrade --install will install the first time and update subsequent times (idempotent).
      helm upgrade --install dapr dapr/dapr \
        --version=$DAPR_VERSION \
        --namespace dapr-system \
        --create-namespace \
        --wait
    '''
    retentionInterval: 'P1D'
  }
}
