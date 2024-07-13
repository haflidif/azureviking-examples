$preReqDeployment = @{
    adoResourceGroupName        = "cnappjobs-ado-keda-rg"
    adoUserAssignedIdentityName = "cnappjobs-ado-keda-mi"
    adoOrganizationName         = "azureviking" # Just the name of the organization, without the https://dev.azure.com/
    adoPoolName                 = "cnappjobs-ado-keda-pool"
    location                    = "westeurope"
    subscriptionId              = "c5c400ba-8a3f-412b-8b13-61832470335a" # Replace with your subscription ID
    tenantId                    = "d0ffafd1-fa67-472b-a574-4dcf8234a4f2" # Replace with your tenant ID
    runOnlyPreReq               = $true
}



.\bicep-deploy.ps1 @preReqDeployment

$prefix = "ado-keda-demo"

$environmentParameters = @{
    resourcePrefix              = $prefix
    adoResourceGroupName        = "$($prefix)-rg"
    adoUserAssignedIdentityName = "$($prefix)-mi"
    adoOrganizationName         = "azureviking" # Just the name of the organization, without the https://dev.azure.com/
    adoPoolName                 = "$($prefix)-pool"
    location                    = "westeurope"
    subscriptionId              = "c5c400ba-8a3f-412b-8b13-61832470335a" # Replace with your subscription ID
    tenantId                    = "d0ffafd1-fa67-472b-a574-4dcf8234a4f2" # Replace with your tenant ID
    runOnlyPreReq               = $true
}

.\bicep-deploy.ps1 @environmentParameters -WhatIf