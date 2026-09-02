<#
.SYNOPSIS
    Sync user attributes from UKG Pro to Active Directory using Report-as-a-Service API and SQL.

.DESCRIPTION
    Uses UKG Pro's Report-as-a-Service (RaaS) SOAP API to retrieve custom Cognos reports
    and imports the data into SQL Server. Faster than REST API for large datasets due to
    session-based streaming. Designed to run in Azure Automation.

    The RaaS API requires 5 steps:
    1. LogOn (create session)
    2. GetReportList (enumerate available reports)
    3. ExecuteReport (run the report)
    4. RetrieveReport (stream Base64 results)
    5. LogOff (end session)

.NOTES
    Author: 00Shep
    Published: 2021-03-10

    This method is faster for large datasets compared to the REST API approach.
    HR staff can author custom reports via Cognos Analytics.

.PARAMETER DataServiceUrl
    UKG Pro Data Service URL (from Automation Variables)

.PARAMETER StreamingServiceUrl
    UKG Pro Streaming Service URL (from Automation Variables)

.PARAMETER ReportName
    Name of the Cognos report to execute

.EXAMPLE
    # Configure in Azure Automation:
    # Variables: UltiPro Data Service URL, UltiPro Streaming Service URL, UltiPro Report Name
    # Credentials: UltiPro Web API User

.LINK
    https://developer.ukg.com/hcm/docs/reports-as-a-service
#>

#Requires -Module Az.Automation

# ============================================
# INITIALIZE VARIABLES FROM AUTOMATION LIBRARY
# ============================================

$dataserviceUrl = Get-AutomationVariable -Name 'UltiPro Data Service URL'
$streamingserviceUrl = Get-AutomationVariable -Name 'UltiPro Streaming Service URL'
$ClientAccessKey = Get-AutomationVariable -Name 'UltiPro ClientAccessKey'
$UserAccessKey = Get-AutomationVariable -Name 'UltiPro UserAccessKey'
$apiuser = Get-AutomationPSCredential -Name 'UltiPro Web API User'
$reportname = Get-AutomationVariable -Name 'UltiPro Report Name'

# Extract secure password string from account storage to plain text
$username = $apiuser.username
$password = [System.Net.NetworkCredential]::new("", $apiuser.password).Password

# Configure reusable http header
$headers = @{'Content-Type' = 'application/soap+xml; charset=utf-8' }

# Reset variables
$serviceID = ""
$token = ""
$InstanceKey = ""

###########################################
# LOGON TO ULTIPRO REPORT-AS-A-SERVICE API
###########################################

Write-Output "Connecting to Report-as-a-Service API"

$body = @"
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <LogOn xmlns="http://www.ultipro.com/dataservices/bidata/2">
      <logOnRequest>
        <ServiceRoot>$dataserviceUrl</ServiceRoot>
        <Credentials>
          <UserName>$username</UserName>
          <Password>$password</Password>
          <ClientAccessKey>$ClientAccessKey</ClientAccessKey>
          <UserAccessKey>$UserAccessKey</UserAccessKey>
        </Credentials>
      </logOnRequest>
    </LogOn>
  </soap12:Body>
</soap12:Envelope>
"@

[xml]$logon = Invoke-RestMethod -Method POST -Uri $dataserviceUrl -Headers $headers -Body $body -Credential $cred

###########################################
# SET SESSION SPECIFIC IDS
###########################################

Write-Output "Fetching session IDs"

$serviceID = $logon.Envelope.body.LogOnResponse.LogOnResult.serviceID
$token = $logon.Envelope.body.LogOnResponse.LogOnResult.Token
$InstanceKey = $logon.Envelope.body.LogOnResponse.LogOnResult.InstanceKey

Write-Output "Session ID: $serviceID"

###########################################
# GET REPORT LIST
###########################################

Write-Output "Enumerating report list"

$body = @"
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <GetReportList xmlns="http://www.ultipro.com/dataservices/bidata/2">
      <getReportListRequest>
        <ServiceRoot>$dataserviceUrl</ServiceRoot>
        <Credentials>
          <ServiceID>$serviceID</ServiceID>
          <ClientAccessKey>$ClientAccessKey</ClientAccessKey>
          <Token>$token</Token>
          <Status>Ok</Status>
        </Credentials>
        <Context>
          <InstanceKey>$instanceKey</InstanceKey>
        </Context>
      </getReportListRequest>
    </GetReportList>
  </soap12:Body>
</soap12:Envelope>
"@

[xml]$ReportList = Invoke-RestMethod -Method POST -Uri $dataserviceUrl -Headers $headers -Body $body -Credential $cred

$reportscount = ($reportlist.Envelope.body.GetReportListResponse.GetReportListResult.reports.Report).count
Write-Output "Reports Found: $reportscount"

###########################################
# EXECUTE REPORT
###########################################

Write-Output "Executing AD Sync Report"

# Get report based on name defined in UltiPro
$reportPath = $ReportList.Envelope.body.GetReportListResponse.GetReportListResult.Reports.Report |
    Where-Object { $_.reportname -eq "$reportname" } |
    Select-Object -ExpandProperty ReportPath

# Specify delimiter in header (if not specified, defaults to XML)
$executeHeaders = @{
    'Content-Type' = 'application/soap+xml; charset=utf-8';
    'US-DELIMITER' = ",";
}

# Configure XML Header/Body payload for Execute Invoke REST
$body = @"
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <ExecuteReport xmlns="http://www.ultipro.com/dataservices/bidata/2">
      <executeReportRequest>
        <ReportPath>$ReportPath</ReportPath>
        <ReportParameters>
        </ReportParameters>
        <Credentials>
          <ServiceID>$serviceID</ServiceID>
          <ClientAccessKey>$ClientAccessKey</ClientAccessKey>
          <Token>$token</Token>
          <Status>Ok</Status>
        </Credentials>
        <Context>
          <InstanceKey>$instanceKey</InstanceKey>
        </Context>
      </executeReportRequest>
    </ExecuteReport>
  </soap12:Body>
</soap12:Envelope>
"@

[xml]$execute = Invoke-RestMethod -Method POST -Uri $dataserviceUrl -Headers $executeHeaders -Body $body

# Set the report key retrieved during execution to be used in the report streaming steps next
$reportKey = $execute.Envelope.body.ExecuteReportResponse.ExecuteReportResult.ReportKey
Write-Output "ReportKey: $reportkey"

###########################################
# RETRIEVE REPORT
###########################################

Write-Output "Fetching report results output"

# Set retrieval header and specify stream output
$retrieveReportURL = $streamingserviceUrl + '?EmploymentStatus=A'
$retrieveHeaders = @{
    'Content-Type'    = 'application/soap+xml; charset=utf-8';
    'Accept-Encoding' = 'gzip, deflate';
}

# Stream output SOAP body
$body = @"
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <RetrieveReport xmlns="http://www.ultipro.com/dataservices/bistream/2">
      <context>
        <ReportKey>$reportKey</ReportKey>
        <ServiceRoot>$streamingserviceUrl</ServiceRoot>
      </context>
    </RetrieveReport>
  </soap12:Body>
</soap12:Envelope>
"@

$response = Invoke-RestMethod -Method POST -Uri $retrieveReportURL -Headers $retrieveHeaders -Body $body

###########################################
# LOGOFF
###########################################

Write-Output "Disconnecting session"

# Disconnect from the data service API
$body = @"
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <LogOff xmlns="http://www.ultipro.com/dataservices/bidata/2">
      <logOffRequest>
        <ServiceRoot>$dataserviceUrl</ServiceRoot>
        <Credentials>
          <ServiceID>$serviceID</ServiceID>
          <ClientAccessKey>$ClientAccessKey</ClientAccessKey>
          <Token>$token</Token>
          <Status>Ok</Status>
        </Credentials>
        <Context>
          <InstanceKey>$InstanceKey</InstanceKey>
        </Context>
      </logOffRequest>
    </LogOff>
  </soap12:Body>
</soap12:Envelope>
"@

Invoke-RestMethod -Method POST -Uri $dataserviceUrl -Headers $headers -Body $body

###########################################
# CONVERT BASE64 TO ARRAY
###########################################

Write-Output "Converting report stream data from Base64 to array/table format"

# Convert output from Base64 to string data (comes out as CSV)
$bytes = [Convert]::FromBase64String($response.Envelope.body.StreamReportResponse.ReportStream)
$csvdata = [System.Text.Encoding]::ASCII.GetString($bytes)
$arraydata = $csvdata | ConvertFrom-Csv

###########################################
# FIND MANAGERS
###########################################

$managers = Get-ADUser -Filter * -Properties employeeID, Manager |
    Where-Object {
    $_.employeeID -notlike "666666" -and
    $_.employeeID -notlike "888888" -and
    $_.employeeID -notlike "999999" -and
    $_.employeeID -ne $null
} | Select-Object employeeID, Manager, distinguishedname

###########################################
# OUTPUT ULTIPRO TO SQL
###########################################

Write-Output "Creating empty SQL data table in memory"

# Build an empty data table in the expected SQL format
[System.Data.DataTable]$table = New-Object('system.Data.DataTable')
$table.Columns.Add("givenName", "System.String")
$table.Columns.Add("middleName", "System.String")
$table.Columns.Add("lastName", "System.String")
$table.Columns.Add("telephoneNumber", "System.String")
$table.Columns.Add("homePhone", "System.String")
$table.Columns.Add("streetAddress", "System.String")
$table.Columns.Add("city", "System.String")
$table.Columns.Add("state", "System.String")
$table.Columns.Add("postalCode", "System.String")
$table.Columns.Add("physicalDeliveryOfficeName", "System.String")
$table.Columns.Add("department", "System.String")
$table.Columns.Add("Title", "System.String")
$table.Columns.Add("company", "System.String")
$table.Columns.Add("employeeID", "System.String")
$table.Columns.Add("division", "System.String")
$table.Columns.Add("orglevel2code", "System.String")
$table.Columns.Add("orglevel3code", "System.String")
$table.Columns.Add("employeeStatusCode", "System.String")
$table.Columns.Add("ManagerEmployeeID", "System.String")
$table.Columns.Add("preferredName", "System.String")
$table.Columns.Add("mail", "System.String")
$table.Columns.Add("location", "System.String")
$table.Columns.Add("jobCode", "System.String")

Write-Output "Adding report data to PowerShell SQL data table object"

foreach ($aRow in $arraydata)
{
    $row = $table.NewRow()

    $row.givenName = $arow.FirstName

    if ($arow.MiddleName.length -ne 0)
    { $row.middleName = $arow.MiddleName.Substring(0, 1) }

    $row.lastName = $arow.LastName
    $row.telephoneNumber = $arow.WorkPhone
    $row.homePhone = $arow.HomePhone
    $row.streetAddress = $arow.Address
    $row.city = $arow.City
    $row.state = $arow.State
    $row.postalCode = $arow.Zip
    $row.physicalDeliveryOfficeName = $arow.Address
    $row.department = $arow.OrgLevel2
    $row.Title = $arow.Title
    $row.company = $arow.Company
    $row.employeeID = $arow.EmployeeNumber
    $row.division = $arow.OrgLevel1Code
    $row.orglevel2code = $arow.OrgLevel2Code
    $row.orglevel3code = $arow.OrgLevel3Code
    $row.employeeStatusCode = $arow.EmployeeStatus
    $row.ManagerEmployeeID = $arow.EmployeeNumberSupervisor

    $table.Rows.Add($row)
}

$tablecount = $table.Rows.count
Write-Output "Discovered $tablecount employee records"

Write-Output "Connecting to SQL Instance"

# Create Connection string - UPDATE SERVER NAME
$cnString = 'Integrated Security=SSPI;Persist Security Info=False;Initial Catalog=DBMaintenance;Data Source=SERVERNAMEHERE'

# Define empty system objects for command and connection strings
[System.Data.SqlClient.SqlCommand]$cmd = New-Object('system.data.sqlclient.sqlcommand')
[System.Data.SqlClient.SqlConnection]$c = New-Object('system.data.sqlclient.sqlconnection')

# Set $c to connection string and open connection
$c.connectionstring = $cnString;
$c.open();

Write-Output "Executing SQL stored procedure"

# Configure command type as stored procedure
$cmd.Connection = $c;
$cmd.CommandType = [System.Data.CommandType]::StoredProcedure
$cmd.commandText = "dbo.ADSync_InsertAll"
$perfResultsParam = New-Object('system.data.sqlclient.sqlparameter')

# SQL table type param
$perfResultsParam.ParameterName = "ADSyncT"
$perfResultsParam.SqlDBtype = [System.Data.SqlDbType]::Structured
$perfResultsParam.Direction = [System.Data.ParameterDirection]::Input
$perfResultsParam.value = $table

$cmd.parameters.add($perfResultsParam);
$cmd.executeNonQuery();

Write-Output "Disconnecting from SQL Instance"
$c.close();

Write-Output "Data retrieval and import complete"

###########################################
# OUTPUT AD DATA TO SQL
###########################################

Write-Output "Creating empty SQL data table in memory"

# Build an empty data table in the expected SQL format
[System.Data.DataTable]$table2 = New-Object('system.Data.DataTable')
$table2.Columns.Add("employeeID", "System.String")
$table2.Columns.Add("distName", "System.String")

Write-Output "Adding data to PowerShell SQL data table object"

foreach ($manager in $managers)
{
    $row = $table2.NewRow()

    $row.employeeID = $manager.employeeID
    $row.distName = $manager.distinguishedname

    $table2.Rows.Add($row)
}

$table2count = $table2.Rows.count
Write-Output "Discovered $table2count employee records"

Write-Output "Connecting to SQL Instance"

# Create Connection string - UPDATE SERVER NAME
$cnString = 'Integrated Security=SSPI;Persist Security Info=False;Initial Catalog=DBMaintenance;Data Source=SERVERNAMEHERE'

# Define empty system objects for command and connection strings
[System.Data.SqlClient.SqlCommand]$cmd = New-Object('system.data.sqlclient.sqlcommand')
[System.Data.SqlClient.SqlConnection]$c = New-Object('system.data.sqlclient.sqlconnection')

# Set $c to connection string and open connection
$c.connectionstring = $cnString;
$c.open();

Write-Output "Executing SQL stored procedure"

# Configure command type as stored procedure
$cmd.Connection = $c;
$cmd.CommandType = [System.Data.CommandType]::StoredProcedure
$cmd.commandText = "dbo.ADDist_InsertAll"
$perfResultsParam = New-Object('system.data.sqlclient.sqlparameter')

# SQL table type param
$perfResultsParam.ParameterName = "ADDistT"
$perfResultsParam.SqlDBtype = [System.Data.SqlDbType]::Structured
$perfResultsParam.Direction = [System.Data.ParameterDirection]::Input
$perfResultsParam.value = $table2

$cmd.parameters.add($perfResultsParam);
$cmd.executeNonQuery();

Write-Output "Disconnecting from SQL Instance"
$c.close();

Write-Output "AD Data retrieval and import complete"
