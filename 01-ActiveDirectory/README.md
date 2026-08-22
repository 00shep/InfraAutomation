# Active Directory Management

PowerShell scripts and techniques for Active Directory administration.

## Contents

- [Bulk Operations](#bulk-operations)
  - [Bulk Update Home Folder Paths](#bulk-update-home-folder-paths)
  - [Bulk Update Logon Scripts](#bulk-update-logon-scripts)
  - [Bulk Update User UPNs](#bulk-update-user-upns)
- [Query and Search](#query-and-search)
  - [Find Inactive Computer Objects](#find-inactive-computer-objects)
  - [Find Users with Specific UPN Suffix](#find-users-with-specific-upn-suffix)
  - [Find Servers Not in a Group (LDAP Query)](#find-servers-not-in-a-group-ldap-query)
- [Maintenance Scripts](#maintenance-scripts)
  - [Find Orphaned Home Drives](#find-orphaned-home-drives)

---

## Bulk Operations

### Bulk Update Home Folder Paths

**Published:** 2015-06-19

Update home directory paths for all enabled users in a specific OU.

```powershell
# CHANGE HOME DIRECTORY
$SearchOU = "OU=Users,DC=contoso,DC=com"

Import-Module ActiveDirectory

# Search for all users in OU that are not disabled or with blank homedirectory
Get-ADUser -Filter * -SearchBase $SearchOU | 
    Where-Object {$_.enabled -eq $true -AND $_.homedirectory -ne ""} | 
    ForEach-Object {
        $sam = $_.SamAccountName
        Set-ADUser -Identity $_ -HomeDrive "H:" -HomeDirectory "\\SERVER02\Users\$sam"
    }
```

**Usage:**
1. Update `$SearchOU` to target your specific organizational unit
2. Update the server path (`\\SERVER02\Users\`) to your file server
3. Run with appropriate AD admin credentials

---

### Bulk Update Logon Scripts

**Published:** 2015-06-19

Update logon script paths for all users in a specific OU.

```powershell
# CHANGE LOGON SCRIPT
Import-Module ActiveDirectory

Get-ADUser -Filter * -SearchBase "OU=Users,DC=contoso,DC=com" | 
    ForEach-Object {
        Set-ADUser -Identity $_ -ScriptPath "LOGON-NEW.bat"
    }
```

**Usage:**
1. Update the `-SearchBase` to target your OU
2. Update `"LOGON-NEW.bat"` to your script name
3. Ensure the script exists in the NETLOGON share

---

### Bulk Update User UPNs

**Published:** 2015-10-22

Bulk update User Principal Name suffixes for domain migrations or consolidations.

```powershell
# Bulk Update UPNs
Import-Module ActiveDirectory

# SPECIFY NEW SUFFIX AND OU TO CHANGE
$newSuffix = '@domain.com'
$ou = "OU=Users,DC=mydomain,DC=local"

# EXECUTE CHANGES
Get-ADUser -Filter * -SearchBase $ou | 
    ForEach-Object {
        $newUpn = $_.SamAccountName + $newSuffix
        Set-ADUser -Identity $_ -UserPrincipalName $newUpn
    }
```

**Usage:**
1. Update `$newSuffix` to your target UPN suffix
2. Update `$ou` to target the correct organizational unit
3. Consider testing on a small subset first
4. Useful for domain migrations or post-merger consolidations

---

## Query and Search

### Find Inactive Computer Objects

**Published:** 2015-10-21

Find all computer accounts that haven't contacted the domain in 8 weeks or more.

```powershell
dsquery computer -inactive 8 | Sort-Object
```

**Usage:**
- Change `8` to the number of weeks of inactivity
- Can be used for user objects as well: `dsquery user -inactive 8`
- Sorted output helps if you have a computer naming convention
- Use results to clean up stale computer accounts

---

### Find Users with Specific UPN Suffix

**Published:** 2015-11-04

Find and export all users with a specific UPN suffix.

```powershell
$ou = "OU=Users,DC=mydomain,DC=local"
Get-ADUser -Filter * -SearchBase $ou | 
    Where-Object {$_.UserPrincipalName -like "*@domain.com"} | 
    Export-Csv C:\temp\UPN.csv -NoTypeInformation
```

**Usage:**
1. Update `$ou` to your search base
2. Update `*@domain.com` to the UPN suffix you're searching for
3. Update the export path as needed
4. Useful for auditing or validation during domain migrations

---

### Find Servers Not in a Group (LDAP Query)

**Published:** 2015-10-21

LDAP filter to find all Windows Servers that are NOT members of a specific group, with recursive group membership checking.

**LDAP Filter:**
```ldap
(&(objectCategory=computer)(operatingSystem=*Windows Server*)(!memberof:1.2.840.113556.1.4.1941:=CN=ServerHardening,OU=Groups,DC=mydomain,DC=local))
```

**Filter Components:**

| Component | Meaning |
|-----------|---------|
| `&` | AND the following conditions together |
| `objectCategory` | Object type filter (user, computer, etc.) |
| `operatingSystem` | Value from the computer object's "Operating System" attribute |
| `!` | NOT operator (negates the condition) |
| `memberof` | Group membership filter |
| `1.2.840.113556.1.4.1941` | OID for recursive group membership (LDAP_MATCHING_RULE_IN_CHAIN) |

**Usage:**
1. Replace the group DN with your target group's distinguished name
2. Can adjust `operatingSystem` to match specific OS versions (e.g., `*Windows Server 2019*`)
3. Can extend to check multiple groups by adding more `(!memberof:...)` conditions
4. Use in Active Directory Users and Computers (Advanced Features), LDP.exe, or PowerShell with `Get-ADComputer -LDAPFilter`

**Example - PowerShell:**
```powershell
$ldapFilter = "(&(objectCategory=computer)(operatingSystem=*Windows Server*)(!memberof:1.2.840.113556.1.4.1941:=CN=ServerHardening,OU=Groups,DC=mydomain,DC=local))"
Get-ADComputer -LDAPFilter $ldapFilter | Select-Object Name, OperatingSystem
```

---

## Maintenance Scripts

### Find Orphaned Home Drives

**Published:** 2016-05-11  
**Script:** [`Find-OrphanedHomeDrives.ps1`](./Find-OrphanedHomeDrives.ps1)

Identifies home drive folders for deleted Active Directory accounts and reports folder sizes for cleanup planning.

**What it does:**
1. Scans all folders in the home drives directory
2. Tests each folder name against Active Directory users
3. If the user doesn't exist, calculates the folder size in MB
4. Exports folder name and size to a text file
5. Provides a total size of all orphaned folders

**Usage:**

```powershell
# Default behavior (H:\Users)
.\Find-OrphanedHomeDrives.ps1

# Custom path
.\Find-OrphanedHomeDrives.ps1 -HomeDrivePath "\\fileserver\home$" -OutputFile "C:\Reports\orphaned.csv"
```

**Output Example:**
```
jdoe,450
asmith,1200
rjones,75
---------------------((TOTAL))
1725
```

**Notes:**
- Review the output before deleting any folders
- Consider archiving instead of immediate deletion
- Some folders may be service accounts or intentionally orphaned
- Useful for reclaiming disk space during cleanup projects

---

*Originally published on Shep's IT Solutions blog (2015-2016)*
