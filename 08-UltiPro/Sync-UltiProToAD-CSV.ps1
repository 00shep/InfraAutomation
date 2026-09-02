<#
.SYNOPSIS
    Sync user attributes from UltiPro/UKG Pro to Active Directory using REST APIs.

.DESCRIPTION
    Uses UltiPro's REST APIs to pull employee data (employment details, personal info,
    org levels) and exports to CSV for consumption by AD sync tools like ManageEngine
    ADManager. Designed to run in Azure Automation with Hybrid Worker for on-prem access.

.NOTES
    Author: 00Shep
    Published: 2020-10-08

    IMPORTANT - Authentication Update (2024+):
    UKG Pro now uses OAuth 2.0 instead of basic authentication.
    You must update the authentication section to use Bearer tokens.
    See: https://developer.ukg.com/hcm/reference/welcome-to-the-ukg-pro-api

.PARAMETER WebServiceAccount
    Automation credential for UKG Pro API service account

.PARAMETER ADManagerRunAsAccount
    Automation credential for accessing file share

.PARAMETER CustomerAPIKey
    UKG Pro customer API key (stored in Automation Variables)

.PARAMETER ExportPath
    UNC path for CSV export file

.EXAMPLE
    # Run in Azure Automation Runbook
    $webserviceaccount = Get-AutomationPSCredential -Name 'UltiPro Sync User'
    $ADManagerRunAsAccount = Get-AutomationPSCredential -Name 'ADManager Runas Account'
    $exportpath = "\\fileserver\share\UltiPro-User-Data"

    # Execute script
#>

#Requires -Module Az.Automation

# ============================================
# CONFIGURATION - Update these values
# ============================================

$webserviceaccount = Get-AutomationPSCredential -Name 'UltiPro Sync User'
$ADManagerRunAsAccount = Get-AutomationPSCredential -Name 'ADManager Runas Account'
$exportpath = "\\FILEPATHHERE\UltiPro-User-Data"
$exportFile = '\Employee-Data.csv'

# IMPORTANT: Authentication has changed to OAuth 2.0
# Update this section to use Bearer token authentication
# See migration notes in README.md
$headers = @{'us-customer-api-key' = '#####'}

############################################
# GET ACTIVE EMPLOYEES FROM ULTIPRO APIS
############################################

# Collecting all active UltiPro users, 200 at a time. They do not support more than that through the API in one request.
# https://developer.ukg.com/hcm/docs/employee-employment-information-service

Write-Output "Searching Employment Details API for active employees"

$a = 0
$employees = @()
$AgeObjCount = ""

do {
    $a++
    $tempObj = $null
    $URL = "https://service5.ultipro.com/personnel/v1/employment-details?employeeStatusCode!=T&primaryProjectCode=COMPUTER&per_page=200&page=$a"
    $tempObj = Invoke-RestMethod -Method 'Get' -Uri $url -Credential $webserviceaccount -Headers $headers

    If ($tempObj.Count -ne 0)
    { $employees += $tempObj }
    else
    { $AgeObjCount = "end" }

} until ($AgeObjCount -eq "end")

$count = $employees.count
Write-Output "Found $count employees"

############################################################
# GET ORG LEVEL DETAILS FROM ULTIPRO APIS
############################################################

# Org level description is not part of the normal employee details
# This lookup pulls the descriptions for later usage as "Department Name"
# https://developer.ukg.com/hcm/docs/employee-employment-information-service

Write-Output "Searching Org Level Details API for Company / Department Info"

$URL = "https://service5.ultipro.com/configuration/v1/org-levels"
$OrgLevels = Invoke-RestMethod -Method 'Get' -Uri $url -Credential $webserviceaccount -Headers $headers
$SecondOrgLevels = $OrgLevels | Where-Object { $_.level -eq "2" }

############################################################
# COLLECT ADDITIONAL EMPLOYEE DETAILS FOR ACTIVE EMPLOYEES
############################################################

# Loop through all employees
# Load supervisor from AD based on the supervisor employee number
# Load name, address, etc. from the Employee Changes API

Write-Output "Assembling employee details array"

$ObjectArray = New-Object System.Collections.Generic.List[System.Object]

foreach ($employee in $employees)
{
    if ($employee.supervisorEmployeeNumber.length -ne 0)
    {
        $manager = Get-ADUser -Filter * -Properties EmployeeID |
            Where-Object { $_.employeeID -eq $employee.supervisorEmployeeNumber } |
            Select-Object Name, distinguishedname
    }

    $employeeID = $employee.employeeID

    # Query Employee Changes API for specific employeeID vs. all employees
    # https://developer.ukg.com/hcm/docs/employee-employment-information-service
    $URL = "https://service5.ultipro.com/personnel/v1/employee-changes/$employeeID"
    $employeeChanges = Invoke-RestMethod -Method 'Get' -Uri $url -Credential $webserviceaccount -Headers $headers

    # Select only active records; it is possible that 1 employeeID can return multiple records
    # if the person was terminated and rehired at a later date
    $employeeChangesActive = $employeeChanges | Where-Object { $_.employeeStatus -eq "A" }

    $department = $SecondOrgLevels | Where-Object { $_.code -eq $employee.orgLevel2Code }

    # Build temporary array to house data from difference sources
    $tempArray = New-Object System.Object

    $middle = ""
    if ($employeeChangesActive.middleName.length -ne 0)
    { $middle = ($employeeChangesActive.middleName).substring(0, 1) }

    $WorkPhone = $null
    if ($employeeChangesActive.workPhone)
    { $WorkPhone = "{0:+1 ###-###-####}" -f ($employeeChangesActive.workPhone -as [int64]) }

    # Add attributes from employee-changes API
    $tempArray | Add-Member -MemberType NoteProperty -Name "givenName" -Value $employeeChangesActive.firstName
    $tempArray | Add-Member -MemberType NoteProperty -Name "middleName" -Value $middle
    $tempArray | Add-Member -MemberType NoteProperty -Name "sn" -Value $employeeChangesActive.lastName
    $tempArray | Add-Member -MemberType NoteProperty -Name "telephoneNumber" -Value $WorkPhone
    $tempArray | Add-Member -MemberType NoteProperty -Name "homePhone" -Value $employeeChangesActive.homePhone
    $tempArray | Add-Member -MemberType NoteProperty -Name "streetAddress" -Value $employeeChangesActive.employeeAddress1
    $tempArray | Add-Member -MemberType NoteProperty -Name "streetAddress2" -Value $employeeChangesActive.employeeAddress2
    $tempArray | Add-Member -MemberType NoteProperty -Name "l" -Value $employeeChangesActive.city
    $tempArray | Add-Member -MemberType NoteProperty -Name "st" -Value $employeeChangesActive.state
    $tempArray | Add-Member -MemberType NoteProperty -Name "postalCode" -Value $employeeChangesActive.zipCode
    $tempArray | Add-Member -MemberType NoteProperty -Name "physicalDeliveryOfficeName" -Value $employeeChangesActive.employeeAddress1

    # Add attributes from Organization Levels API
    $tempArray | Add-Member -MemberType NoteProperty -Name "department" -Value $department.description

    # Add attributes from employment-details API
    $tempArray | Add-Member -MemberType NoteProperty -Name "Title" -Value $employee.jobDescription
    $tempArray | Add-Member -MemberType NoteProperty -Name "Company" -Value $employee.companyName
    $tempArray | Add-Member -MemberType NoteProperty -Name "employeeID" -Value $employee.employeeNumber
    $tempArray | Add-Member -MemberType NoteProperty -Name "division" -Value $employee.orglevel1code
    $tempArray | Add-Member -MemberType NoteProperty -Name "extensionAttribute11" -Value $employee.orgLevel2Code
    $tempArray | Add-Member -MemberType NoteProperty -Name "extensionAttribute12" -Value $employee.orgLevel3Code
    $tempArray | Add-Member -MemberType NoteProperty -Name "extensionAttribute13" -Value $employee.employeeStatusCode
    $tempArray | Add-Member -MemberType NoteProperty -Name "employeeIDinUltiPro" -Value $employee.employeeID

    # Add Manager from AD referenced from employment-details API
    $tempArray | Add-Member -MemberType NoteProperty -Name "Manager" -Value $manager.distinguishedname

    # Potential future fields
    #$tempArray | Add-Member -MemberType NoteProperty -Name "preferredName" -Value $employeeChangesActive.preferredName
    #$tempArray | Add-Member -MemberType NoteProperty -Name "mail" -Value $employeeChangesActive.emailAddress
    #$tempArray | Add-Member -MemberType NoteProperty -Name "location" -Value $employeeChangesActive.workLocation
    #$tempArray | Add-Member -MemberType NoteProperty -Name "jobCode" -Value $employeeChangesActive.jobCode

    $objectarray.add($tempArray)
}

Write-Output "Exporting aggregated employee list to CSV for consumption"

New-PSDrive -Name "L" -PSProvider FileSystem -Root $exportpath -Credential $ADManagerRunAsAccount
$ObjectArray | Export-CSV "L:\$exportFile" -NoTypeInformation
Remove-PSDrive -Name "L"

Write-Output "Export complete: $($ObjectArray.Count) employee records"
