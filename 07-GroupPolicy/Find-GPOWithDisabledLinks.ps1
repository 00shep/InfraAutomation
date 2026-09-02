<#
.SYNOPSIS
    Find Group Policy Objects that have links, but all links are disabled.

.DESCRIPTION
    Searches all GPOs in the domain and identifies those that have links to OUs/sites/domains
    but all of those links are disabled. These GPOs exist and are linked, but won't apply
    to any computers or users until the links are enabled.

.NOTES
    Author: 00Shep
    Published: 2019-07-02

    Note: This script can take a few minutes to run depending on the number of GPOs.

.EXAMPLE
    .\Find-GPOWithDisabledLinks.ps1
    Displays all GPOs with disabled links in a grid view

.OUTPUTS
    List of GPO names that have only disabled links
#>

#Requires -Module GroupPolicy

# Parse XML "<LinksTo>\<Enabled>" looking for $false entries. Output list.
# Can take a few minutes to run

$disabledlinks = New-Object System.Collections.Generic.List[System.Object]
$GPOs = Get-GPO -All

ForEach ($gpo in $GPOs)
{
    [xml]$gpoxml = Get-GPOReport -Guid $gpo.Id -ReportType Xml

    if (($gpoxml).GPO.LinksTo.Enabled -eq $false)
    {
        $disabledlinks.Add($gpoxml.GPO.Name)
    }
}

$disabledlinks | Out-GridView -Title "Group Policy Objects with Disabled Links"
