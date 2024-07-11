// MARK: Parameters
//Define your parameters
//https://github.com/haflidif/azureviking-examples/blob/main/Azure-DevOps-Scalable-Agents-ContainerAppJobs-KEDA
param nameprefix string
@description('Prefix for all resources created by this template.')
param location string = resourceGroup().location
@description('The location where the resources will be deployed')
param poolName string
@description('The name of the AzureDevOps agent pool.')
param azdoOrganizationName string
@description('The name of the Azure DevOps organization without the URL prefix.')
param gitrepo string
@description('The URL of the git repository where the docker file and start.sh script are located.')
param dockerfile string
@description('The name of the docker file to be used for the container')
param imageName string
@description('The name of the image to be used for the container.')
param userAssignedIdentityName string
@description('The name of the user assigned identity.')
param vnetAddressPrefixes array
@description('The address prefix for the virtual network.')
param sharedServiceSubnet object
@description('The subnet for shared services.')
param containerAppSubnet object
@description('The subnet for the container app environment.')
param tags object = {}
@description('Tags to be applied to all resources.')

//Naming Parameters
param vnetName string = '${nameprefix}-vnet'
@description('The name of the virtual network.')
param lawName string = '${nameprefix}-law'
@description('The name of the Log Analytics Workspace.')
param acrName string = replace('${nameprefix}acr', '-', '')
@description('The name of the Azure Container Registry.')
param containerAppEnvName string = '${nameprefix}-cnappenv'
@description('The name of the container app environment.')
param azdoUrl string = 'https://dev.azure.com/${azdoOrganizationName}'

// MARK: - Getting information about User Assigned Identity
// Getting information about User Assigned Identity
resource usrami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

// MARK: Networking Resources
// Create a virtual network, to use for the container app environment
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
    subnets: [ sharedServiceSubnet, containerAppSubnet ]
  }
}


// MARK: Log Analytics Workspace
// Create a Log Analytics Workspace for gathering logs from the container app environment.
resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${lawName}-${take(uniqueString(resourceGroup().id), 5)}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}


// MARK: Azure Container Registry
// Create an Azure Container Registry to store the container images.
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: '${acrName}${take(uniqueString(resourceGroup().id), 5)}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${usrami.id}': {}
    }
  }
  sku: {
    name: 'Basic'
    //Premium SKU is required for private endpoints.
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    // Required for the deployment script to build the images. Public Network Access, can be disabled after the deployment.
    networkRuleBypassOptions: 'AzureServices'
  }
}

// MARK: Container App Environment
// Create a container app environment to run the container jobs.
resource containerappenv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: law.properties.customerId
        sharedKey: law.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: vnet.properties.subnets[1].id
      internal: true
    }
    zoneRedundant: true
  }
}

// Defining Diagnostic Settings for the Container App Environment
resource containerappenvdiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'containerappenvdiag'
  scope: containerappenv
  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: law.id
  }
}

// MARK: Deployment Scripts for Container App Jobs
// Define the deployment script to build and push the container images to the Azure Container Registry.
resource arcbuild 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'acrbuild'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${usrami.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.61.0'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    arguments: '${acr.name} ${imageName} ${dockerfile} ${gitrepo}'
    scriptContent: '''
    az login --identity
    az acr build --registry $1 --image $2 --file $3 $4
    '''
    cleanupPreference: 'OnSuccess'
 }
}

// MARK: AzDo Placeholder Agent
// Creating the Azure DevOps Placeholder Agent, this is needed as a pool of Self-Hosted agents must have at least one agent in place so the pipeline can be executed on that pool.
resource arcplaceholder 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'acrplaceholder'
  location: location
  tags: union(tags, { Note: 'Can be deleted after original ADO registration (along with the Placeholder Job). Although the Azure resource can be deleted, Agent placeholder in ADO cannot be.' })
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${usrami.id}': {}
    }
  }

  properties: {
    azCliVersion: '2.61.0'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    arguments: '${acr.name} ${imageName} ${poolName} ${resourceGroup().name} ${azdoUrl} ${usrami.properties.clientId} ${containerappenv.name} ${usrami.id}'
    scriptContent: '''
    az login --identity
    az extension add --name containerapp --upgrade --only-show-errors
    az containerapp job create -n 'placeholder' -g $4 --environment $7 --trigger-type Manual --replica-timeout 300 --replica-retry-limit 1 --replica-completion-count 1 --parallelism 1 --image "$1.azurecr.io/$2" --cpu "2.0" --memory "4Gi" --secrets "organization-url=$5" --env-vars "USRMI_ID=$6" "AZP_URL=$5" "AZP_POOL=$3" "AZP_PLACEHOLDER=1" "AZP_AGENT_NAME=dontdelete-placeholder-agent" "APPSETTING_WEBSITE_SITE_NAME=azcli-workaround" --registry-server "$1.azurecr.io" --registry-identity "$8"
    az containerapp job start -n "placeholder" -g $4
    '''
    cleanupPreference: 'OnSuccess'
  }
  dependsOn: [
    arcbuild
    containerappenvdiag
  ]
}

// MARK: AzDo Container App Jobs Agent.
// Creating the Container App Job for the Azure DevOps Agent with KEDA Scaler configuration.
resource azdoagentjob 'Microsoft.App/jobs@2024-02-02-preview' = {
  name: 'azdoagentjob'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${usrami.id}': {}
    }
  }
  properties: {
    environmentId: containerappenv.id

    configuration: {
      triggerType: 'Event'

      secrets: [
        {
          name: 'organization-url'
          value: azdoUrl
        }
        {
          name: 'azp-pool'
          value: poolName
        }
        {
          name: 'user-assigned-identity-client-id'
          value: usrami.properties.clientId
        }
      ]
      replicaTimeout: 1800
      replicaRetryLimit: 1
      eventTriggerConfig: {
        replicaCompletionCount: 1
        parallelism: 1
        scale: {
          minExecutions: 0
          maxExecutions: 10
          pollingInterval: 10 // How often should KEDA Scaler check the queue for new jobs, every x seconds.
          rules: [
            {
              name: 'azure-pipelines'
              type: 'azure-pipelines'

              // https://keda.sh/docs/2.14/scalers/azure-pipelines/
              metadata: {
                poolName: poolName
              }
              auth: [
                {
                  secretRef: 'organization-url'
                  triggerParameter: 'organizationURL'
                }
              ]
              identity: usrami.id // This is to use the User Assigned Identity to authenticate with Azure DevOps Queue.
            }
          ]
        }
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: usrami.id
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${acr.properties.loginServer}/${imageName}'
          name: 'azdoagent'
          env: [
            {
              name: 'USRMI_ID'
              secretRef: 'user-assigned-identity-client-id'
            }
            {
              name: 'AZP_URL'
              secretRef: 'organization-url'
            }
            {
              name: 'AZP_POOL'
              secretRef: 'azp-pool'
            }

            // This is a workaround for a issue that Container App Jobs doesn't detect the correct MSI Endpoint when trying to get a token from Entra ID.
            // By setting APPSETTING_WEBSITE_SITE_NAME to whatever value the token is correctly retrieved from the right endpoint.
            {
              name: 'APPSETTING_WEBSITE_SITE_NAME' 
              value: 'azcli-workaround'
            }
          ]
          resources: {
             cpu: 2
             memory: '4Gi'
          }
        }
      ]
    }
  }
  dependsOn: [
    arcplaceholder
    containerappenvdiag
  ]
}

// MARK: - Outputs
// Defining Outputs to use in the Terraform Infrastructure Bicep Template.
output vnetId string = vnet.id
output vnetName string = vnet.name
output containerSubnetId string = vnet.properties.subnets[1].id
