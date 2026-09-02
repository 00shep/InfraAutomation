<#
.SYNOPSIS
    Check Bitlocker encryption status for SCCM compliance reporting.

.DESCRIPTION
    Queries WMI to verify that Bitlocker is enabled on the C: drive and uses
    AES 256 encryption. Returns "Compliant" or "Non-Compliant" for SCCM
    compliance item reporting.

.NOTES
    Author: 00Shep
    Published: 2017-04-10

    Encryption Methods:
    0 = None
    1 = AES 128 with Diffuser
    2 = AES 256 with Diffuser
    3 = AES 128 (default)
    4 = AES 256 (desired)

    Protection Status:
    0 = Protection disabled
    1 = Protection enabled

.EXAMPLE
    .\Get-BitlockerComplianceStatus.ps1
    Returns "Compliant" if Bitlocker is enabled with AES 256 encryption
#>

$BitlockerStatus = Get-WmiObject -Namespace "root\CIMV2\Security\MicrosoftVolumeEncryption" `
    -Class Win32_EncryptableVolume `
    -ErrorAction Stop |
    Where-Object {$_.DriveLetter -eq "C:"} |
    Select-Object EncryptionMethod, ProtectionStatus

# Status: 0 = disabled, 1 = enabled
# Method: {0 = none, 1 = 128diffuser, 2 = 256 diffuser, 3 = 128(default), 4 = 256(desired)}

# Verify that Bitlocker is enabled and AES 256 is used
if ($BitlockerStatus.ProtectionStatus -eq 1 -and $BitlockerStatus.EncryptionMethod -eq 4) {
    Write-Host "Compliant"
}
else {
    Write-Host "Non-Compliant"
}
