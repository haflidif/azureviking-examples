using './main.bicep'

param nameprefix = 'cnappjobs-ado-keda'
param location = 'westeurope'
param poolName = '${nameprefix}-pool'
param azdoOrganizationName = 'azureviking'
param gitrepo = 'https://github.com/haflidif/agent-docker-files.git#:docker/ado'
param dockerfile = 'dockerfile.ado-pipeline'
param imageName = 'adoagent:1.0'
param vnetAddressPrefixes = ['10.0.0.0/16']
param userAssignedIdentityName = 'cnappjobs-ado-keda-mi'

param sharedServiceSubnet = {
  name: '${nameprefix}-shrsvc-sn'
  properties: {
    addressPrefix: '10.0.0.0/24'
    serviceEndpoints: [
      {
        locations: [
          'westeurope'
        ]
        service: 'Microsoft.KeyVault'
      }
      {
        locations: [
          'westeurope'
        ]
        service: 'Microsoft.Storage'
      }
    ]
  }
}

param containerAppSubnet = {
  name: '${nameprefix}-cnapp-sn'
  properties: {
    addressPrefix: '10.0.2.0/23'
    serviceEndpoints: [
      {
        locations: [
          'westeurope'
        ]
        service: 'Microsoft.KeyVault'
      }
      {
        locations: [
          'westeurope'
        ]
        service: 'Microsoft.Storage'
      }
    ]
  }
}

param tags = {
  environment: 'azdo-agent'
  createdBy: 'Bicep'
}
