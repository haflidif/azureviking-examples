#region Parameters
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $location = "westeurope",
    [Parameter()]
    [string]
    $resourceGroupName = "demo-rg",
    [Parameter()]
    [string]
    $userAssignedIdentityName = "demo-mi",
    [Parameter()]
    [string]
    $subscriptionId = "00000000-0000-0000-0000-000000000000",
    [Parameter()]
    [string]
    $tenantId = "00000000-0000-0000-0000-000000000000",
    [Parameter()]
    [string]
    $adoOrganizationName = "YourOrganizationNameWithoutDevAzureCom",
    [Parameter()]
    [string]
    $adoPoolName = "demo-pool",
    [Parameter(Mandatory = $false)]
    [string]
    $resourcePrefix = "demo"
)
#endregion Parameters

#region Azure Login and Context

# Check if Connect-AzAccount is needed.
$alreadyLoggedIn = Get-AzContext -ErrorAction SilentlyContinue

# Login to Azure using Azure PowerShell if not already logged in.
if ($null -eq $alreadyLoggedIn) {
    try {
        Connect-AzAccount -Tenant $tenantId -Subscription $subscriptionId -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error "Failed to connect to Azure account or select Azure subscription"
        exit 1
    }
}

# Set the right context
try {
    $Context = Set-AzContext -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
    if ($null -eq $Context) {
        Write-Error "Failed to set Azure context"
        exit 2
    }
}
catch {
    Write-Error "Failed to set Azure context"
    exit 2
}
#endregion Azure Login and Context

#region Initialize Variables
# Initialize an array to store the status of the resources
$resourceStatuses = @{}

# Initialize variables to track if resources were created
$resourceGroupCreated = $false
$uamiCreated = $false
$roleAssignmentCreated = $false
$azdoPoolCreated = $false
$uamiAddedToAzDoGroup = $false
#endregion Initialize Variables

#region Azure Resource Group

# Check if the Azure Resource Group already exists
try {
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
}
catch {
    Write-Error "Failed to get Azure resource group"
    return 3
}

# If the resource group does not exist, create it
if ($null -eq $resourceGroup) {
    try {
        $resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location
        $resourceGroupCreated = $true
    }
    catch {
        Write-Error "Failed to create Azure resource group"
        return 4
    }
}

$resourceStatuses["ResourceGroup"] = [PSCustomObject]@{
    "Name"        = $resourceGroup.ResourceGroupName
    "Id"          = $resourceGroup.ResourceId
    "ClientId"    = "N/A"
    "PrincipalId" = "N/A"
    "Status"      = if ($resourceGroupCreated) { "Created" } else { "Already exists" }
}
#endregion Azure Resource Group

#region User Assigned Managed Identity

# Check if the Azure User Assigned Managed Identity already exists
try {
    $uami = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedIdentityName -ErrorAction SilentlyContinue
}
catch {
    Write-Error "Failed to get Azure user assigned managed identity"
    return 5
}

# If the user assigned managed identity does not exist, create it
if ($null -eq $uami) {
    try {
        $uami = New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedIdentityName -Location $location
        $uamiCreated = $true
    }
    catch {
        Write-Error "Failed to create Azure user assigned managed identity"
        return 6
    }
}

$resourceStatuses["UserAssignedIdentity"] = [PSCustomObject]@{
    "Name"        = $uami.Name
    "Id"          = $uami.Id
    "ClientId"    = $uami.ClientId
    "PrincipalId" = $uami.PrincipalId
    "Status"      = if ($uamiCreated) { "Created" } else { "Already exists" }
}

# Wait for the managed identity to be provisioned
if ($uamiCreated) {
    Write-Progress -Activity "Waiting for the user assigned managed identity to be provisioned" -Id 1 -Status "In Progress"
    # Write-Host "Waiting for the user assigned managed identity to be provisioned..."
    Start-Sleep -Seconds 30
    Write-Progress -Activity "Waiting for the user assigned managed identity to be provisioned" -Id 1 -Status "Completed" -Completed
}
#endregion User Assigned Managed Identity

#region Role Assignment
# Check if the Owner role assignment already exists for the user assigned managed identity
try {
    $roleAssignment = Get-AzRoleAssignment -ObjectId $uami.PrincipalId -RoleDefinitionName "Owner" -Scope $resourceGroup.ResourceId -ErrorAction SilentlyContinue
}
catch {
    Write-Error "Failed to get role assignment for the user assigned managed identity"
    return 8
}

# If the role assignment does not exist, create it
if ($null -eq $roleAssignment) {
    try {
        $roleAssignment = New-AzRoleAssignment -ObjectId $uami.PrincipalId -RoleDefinitionName "Owner" -Scope $resourceGroup.ResourceId -ErrorAction Stop
        $roleAssignmentCreated = $true
    }
    catch {
        Write-Error "Failed to assign Owner role to the user assigned managed identity"
        return 9
    }
}

$resourceStatuses["RoleAssignment"] = [PSCustomObject]@{
    "Name"     = $roleAssignment.RoleDefinitionName
    "Identity" = $roleAssignment.DisplayName
    "Scope"    = $roleAssignment.Scope
    "Status"   = if ($roleAssignmentCreated) { "Created" } else { "Already exists" }
}
#endregion Role Assignment

#region Adding Pre-Requisites for Azure DevOps

# Creating Custom Object for the Azure DevOps CLI API to manage service principals.
$servicePrincipalCreation = [PSCustomObject]@{
    area       = "graph"
    resource   = "servicePrincipals"
    apiVersion = "7.2-preview"
}

# Creating Custom Object for the Azure DevOps CLI API to manage pools.
$poolCreation = [PSCustomObject]@{
    area       = "distributedtask"
    resource   = "pools"
    apiVersion = "5.0-preview"
}

# Check if the Azure DevOps Pool already exists
try {
    $azdoPool = $(az devops invoke `
            --org https://dev.azure.com/$adoOrganizationName/ `
            --area $poolCreation.area --resource $poolCreation.resource `
            --http-method GET --api-version $poolCreation.apiVersion `
            --query "value[?name == '$adoPoolName']") | ConvertFrom-Json 
}
catch {
    Write-Error "Failed to get Azure DevOps pool"
    return 10
}
if ($null -eq $azdoPool) {
    try {

        $poolBody = @{
            name          = $adoPoolName
            autoProvision = "true"
            poolType      = 1
            isHosted      = "false"
        }
        
        # $poolInFile = "$PSScriptRoot/poolBody.json"
        $poolInFile = "poolBody.json"
        Set-Content -Path $poolInFile -Value ($poolBody | ConvertTo-Json)
    
        $azdoPool = $(az devops invoke `
                --org https://dev.azure.com/$adoOrganizationName/ `
                --area $poolCreation.area --resource $poolCreation.resource `
                --http-method POST --api-version $poolCreation.apiVersion `
                --in-file $poolInFile) | ConvertFrom-Json
        
        Remove-Item -Path $poolInFile -ErrorAction SilentlyContinue
        $azdoPoolCreated = $true
        Write-Host "Pool $($azdoPool.name) created successfully" -f Green
    }
    catch {
        Write-Error "Failed to create Azure DevOps pool"
        return 11
    }
}

$resourceStatuses["AzureDevOpsPool"] = [PSCustomObject]@{
    "Name"             = $azdoPool.name
    "Id"               = $azdoPool.id
    "OrganizationName" = $adoOrganizationName
    "Status"           = if ($azdoPoolCreated) { "Created" } else { "Already exists" }
}

# Getting the descriptor of the Organization group "Project Collection Service Accounts" in Azure DevOps
$groupDescriptor = $(az devops security group list `
        --org https://dev.azure.com/$adoOrganizationName/ `
        --scope organization `
        --query "graphGroups[?displayName == 'Project Collection Service Accounts']" | ConvertFrom-Json)

try {
    # Getting All Members of the group.
    $uamiAzDoGroupMember = $(az devops security group membership list `
            --org https://dev.azure.com/$adoOrganizationName/ `
            --id $groupDescriptor.descriptor | ConvertFrom-Json)
    
    # Filter the Managed Identity from the existing group members.
    $uamiAzDoGroupMember = $uamiAzDoGroupMember.PSObject.Properties.value | Where-Object { $_.originId -eq $uami.PrincipalId }
}
catch {
    Write-Error "Failed to get Azure DevOps group membership"
    return 12
}
if ($null -eq $uamiAzDoGroupMember) {
    try {
        $spBody = @{
            originId   = $uami.PrincipalId
            storageKey = ""
        }
        $spInfile = "$PSScriptRoot/spBody.json"
        Set-Content -Path $spInfile -Value ($spBody | ConvertTo-Json)
        
        $uamiAzDoGroupMember = $(az devops invoke `
                --org https://dev.azure.com/$adoOrganizationName/ `
                --area $servicePrincipalCreation.area --resource $servicePrincipalCreation.resource `
                --http-method POST --api-version $servicePrincipalCreation.apiVersion `
                --in-file $spInfile --route-parameters groupDescriptors=$groupDescriptor) | ConvertFrom-Json
    
        $addUamiAzDoGroupMember = $(az devops security group membership add `
                --org https://dev.azure.com/$adoOrganizationName/ `
                --group-id $groupDescriptor.descriptor `
                --member-id  $uamiAzDoGroupMember.descriptor) | ConvertFrom-Json
        
        Remove-Item -Path $spInfile
        $uamiAddedToAzDoGroup = $true
        Write-Host "Managed Identity: $($uamiAzDoGroupMember.displayName) added to $($groupDescriptor.displayName)" -f Green
    }
    catch {
        Write-Error "Failed to add Managed Identity to the group"
        return 13
    }
}

$resourceStatuses["AzureDevOpsGroup"] = [PSCustomObject]@{
    "UserAssignedManagedIdentity" = $uamiAzDoGroupMember.displayName
    "GroupName"                   = $groupDescriptor.displayName
    "Id"                          = $groupDescriptor.descriptor
    "Status"                      = if ($uamiAddedToAzDoGroup) { "Added" } else { "Already a member" }
}

#endregion Adding Pre-Requisites for Azure DevOps

# Output the status of the resources
return $resourceStatuses