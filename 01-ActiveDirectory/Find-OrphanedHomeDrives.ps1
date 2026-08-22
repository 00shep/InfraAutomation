<#
.SYNOPSIS
    Find orphaned home drives for deleted Active Directory accounts.

.DESCRIPTION
    This script compares all home drive folders against Active Directory user accounts.
    If a folder exists but the corresponding AD user doesn't, it reports the folder name
    and size in MB. Useful for general housekeeping and reclaiming disk space.

.PARAMETER HomeDrivePath
    The path to the home drives folder. Default: H:\Users

.PARAMETER OutputFile
    The path for the export file. Default: H:\usercomparisonexport.txt

.EXAMPLE
    .\Find-OrphanedHomeDrives.ps1
    Scans H:\Users and exports orphaned folders to H:\usercomparisonexport.txt

.EXAMPLE
    .\Find-OrphanedHomeDrives.ps1 -HomeDrivePath "\\fileserver\home$" -OutputFile "C:\Reports\orphaned.csv"
    Scans a custom path and exports to a custom location

.NOTES
    Author: 00Shep
    Published: 2016-05-11
#>

param(
    [string]$HomeDrivePath = "H:\Users",
    [string]$OutputFile = "H:\usercomparisonexport.txt"
)

# Compare all home drive folders to AD user accounts
# If no match is found, output a file with the user name and folder size in MB
# Add all folders found and output total at the end

$HomeDriveFolders = Get-ChildItem -path $HomeDrivePath | Select-Object -ExpandProperty Name

$totalsize = 0

foreach($folder in $HomeDriveFolders)
{
    $user = ""
    $user = $(try {Get-ADUser $folder | Select-Object -ExpandProperty SAMAccountName} catch {$null})

    if ($user -ne $folder)
    {
        $foldersize = (Get-ChildItem -Path "$HomeDrivePath\$folder" -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $foldersize = [math]::Round($foldersize / 1MB)
        $totalsize = $totalsize + $foldersize
        "$folder,$foldersize" | Out-File $OutputFile -Append
    }
}

"---------------------((TOTAL))",$totalsize | Out-File $OutputFile -Append

Write-Host "Scan complete. Results written to: $OutputFile"
Write-Host "Total orphaned space: $totalsize MB"
