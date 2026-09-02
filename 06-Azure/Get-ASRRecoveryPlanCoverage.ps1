<#
.SYNOPSIS
    Audit Azure Site Recovery Vaults for replicated items missing recovery plan assignments.

.DESCRIPTION
    Azure doesn't have a native way to report on replicated items in a Recovery Vault that
    aren't assigned to a Recovery Plan. This script queries all protected items and recovery
    plans, then identifies which items are not covered by any recovery plan.

.NOTES
    Author: 00Shep
    Published: 2019-07-01

.PARAMETER ResourceGroup
    The Azure resource group containing the Recovery Services Vault

.PARAMETER VaultName
    The name of the Recovery Services Vault to audit

.PARAMETER ConfigServer
    The friendly name of the ASR configuration server (fabric)

.EXAMPLE
    .\Get-ASRRecoveryPlanCoverage.ps1
    Run the script after setting the variables inline

.EXAMPLE
    $params = @{
        ResourceGroup = "RG-DR"
        VaultName = "Vault-ASR-East"
        ConfigServer = "ConfigSvr01"
    }
    .\Get-ASRRecoveryPlanCoverage.ps1 @params
#>

param(
    [string]$ResourceGroup = "RGNAME",
    [string]$VaultName = "VAULTNAME",
    [string]$ConfigServer = "CONFIGSERVERNAME"
)

Connect-AzAccount

# Get the ASR vault
$vault = Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroup -Name $VaultName

# Set the context of the vault. This is required for all future commands
Set-AzRecoveryServicesAsrVaultContext -Vault $vault

# Fabric is essentially a configuration server
# FriendlyName is the name of the config server. You can just run Get-AzRecoveryServicesAsrFabric to list all the config servers to get the right name
$asrfabric = Get-AzRecoveryServicesAsrFabric -FriendlyName $configServer

# Get the fabric container. It holds the replication policies and type of replication
$asrcontainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $asrfabric

# List all the items that are in a protected state by friendly name and resource ID
$ProtectedVMs = Get-AzRecoveryServicesAsrProtectableItem -ProtectionContainer $asrcontainer |
    Where-Object { $_.ProtectionStatus -eq 'Protected' } |
    Select-Object FriendlyName, ReplicationProtectedItemId |
    Sort-Object FriendlyName

# List all recovery plans
$RecoveryPlans = Get-AzRecoveryServicesAsrRecoveryPlan | Select-Object -ExpandProperty Name

# Array to house all protected items with their recovery plan assignments
$ObjectArray = New-Object System.Collections.Generic.List[System.Object]

# Loop through each recovery plan and extract all protected items
foreach ($recoveryplan in $recoveryplans)
{
    $plandetails = Get-AzRecoveryServicesAsrRecoveryPlan -Name $recoveryplan

    # Loop through groups in the recovery plan
    foreach ($group in $plandetails.Groups)
    {
        foreach ($groupprotecteditem in $group.ReplicationProtectedItems)
        {
            # Match the protected item ID to get the friendly name
            $VMmatch = Get-AzRecoveryServicesAsrProtectableItem -ProtectionContainer $asrcontainer |
                Where-Object { $_.ProtectionStatus -eq 'Protected' -and $_.ReplicationProtectedItemId -eq $groupprotecteditem.id } |
                Select-Object -ExpandProperty FriendlyName

            $tempArray = New-Object System.Object
            $tempArray | Add-Member -MemberType NoteProperty -Name "VMName" -Value $VMmatch
            $tempArray | Add-Member -MemberType NoteProperty -Name "RecoveryPlan" -Value $recoveryplan
            $tempArray | Add-Member -MemberType NoteProperty -Name "Group" -Value $group.name
            $tempArray | Add-Member -MemberType NoteProperty -Name "ProtectedItem" -Value $groupprotecteditem
            $tempArray | Add-Member -MemberType NoteProperty -Name "ID" -Value $groupprotecteditem.id
            $ObjectArray.add($tempArray)
        }
    }
}

# Add protected items that aren't in any recovery plan
foreach ($vm in $ProtectedVMs)
{
    $status = $ObjectArray.VMname.contains($vm.FriendlyName)
    if ($status -eq $false)
    {
        $tempArray = New-Object System.Object
        $tempArray | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.FriendlyName
        $ObjectArray.add($tempArray)
    }
}

# Display results in grid view
$ObjectArray | Out-GridView
