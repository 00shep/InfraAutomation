<#
.SYNOPSIS
    Find Group Policy Objects that are not linked to any organizational unit, site, or domain.

.DESCRIPTION
    Searches all GPOs in the domain and identifies those that have no links (SOMPath is null).
    Unlinked GPOs consume AD resources but aren't being applied anywhere, making them
    candidates for deletion or archival.

.NOTES
    Author: 00Shep
    Published: 2019-07-02

    Note: This script can take a few minutes to run depending on the number of GPOs.

.EXAMPLE
    .\Find-GPOWithNoLinks.ps1
    Displays all unlinked GPOs in a grid view

.OUTPUTS
    List of GPO names that have no links
#>

#Requires -Module GroupPolicy

# Parse XML "<LinksTo>\<SOMPath>" looking for $null entries. Output list.
# Can take a few minutes to run

$unlinkedGPOs = New-Object System.Collections.Generic.List[System.Object]
$GPOs = Get-GPO -All

ForEach ($gpo in $GPOs)
{
    [xml]$gpoxml = Get-GPOReport -Guid $gpo.Id -ReportType Xml

    if (($gpoxml).GPO.LinksTo.SOMPath -eq $null)
    {
        $unlinkedGPOs.Add($gpoxml.GPO.Name)
    }
}

$unlinkedGPOs | Out-GridView -Title "Unlinked Group Policy Objects"
