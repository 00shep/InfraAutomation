# Group Policy Management

PowerShell scripts for Group Policy Object (GPO) auditing and maintenance.

## Contents

- [Find GPOs with No Links](#find-gpos-with-no-links)
- [Find GPOs with Disabled Links](#find-gpos-with-disabled-links)

---

## Find GPOs with No Links

**Published:** 2019-07-02  
**Tags:** PowerShell, GPO, Group Policy  
**Script:** [`Find-GPOWithNoLinks.ps1`](./Find-GPOWithNoLinks.ps1)

### Overview

Identifies Group Policy Objects that aren't linked to any organizational unit, site, or domain. Unlinked GPOs consume Active Directory resources but aren't being applied anywhere, making them candidates for deletion or archival.

### What the Script Does

1. Retrieves all GPOs in the domain using `Get-GPO -All`
2. Generates an XML report for each GPO
3. Parses the XML to check if `LinksTo.SOMPath` is null
4. Adds unlinked GPOs to a list
5. Displays results in a grid view

### Usage

```powershell
.\Find-GPOWithNoLinks.ps1
```

**Performance Note:** Can take several minutes to run in environments with many GPOs.

### Use Cases

1. **GPO Cleanup:** Identify obsolete or test GPOs that can be deleted
2. **Compliance Auditing:** Ensure no unintended unlinked policies exist
3. **Documentation:** Maintain an inventory of GPO link status
4. **Pre-Migration:** Identify GPOs to archive before domain migrations

---

## Find GPOs with Disabled Links

**Published:** 2019-07-02  
**Tags:** PowerShell, GPO, Group Policy  
**Script:** [`Find-GPOWithDisabledLinks.ps1`](./Find-GPOWithDisabledLinks.ps1)

### Overview

Identifies Group Policy Objects that have links to OUs, sites, or domains, but all those links are disabled. These GPOs exist and are linked in the directory structure, but won't apply to any computers or users until the links are enabled.

### What the Script Does

1. Retrieves all GPOs in the domain using `Get-GPO -All`
2. Generates an XML report for each GPO
3. Parses the XML to check if `LinksTo.Enabled` is false
4. Adds GPOs with disabled links to a list
5. Displays results in a grid view

### Usage

```powershell
.\Find-GPOWithDisabledLinks.ps1
```

**Performance Note:** Can take several minutes to run in environments with many GPOs.

### Use Cases

1. **Troubleshooting:** Identify GPOs that should be applying but aren't due to disabled links
2. **Testing Cleanup:** Find GPOs that were disabled for testing but never re-enabled
3. **Change Management:** Verify GPO link states after organizational changes
4. **Security Audit:** Ensure critical security policies aren't inadvertently disabled

---

## Prerequisites

- **Module:** GroupPolicy PowerShell module
- **Permissions:** Read access to Group Policy Objects
- **Platform:** Windows Server with RSAT tools or domain controller

## Installation

Both scripts are standalone and require no installation beyond the GroupPolicy module.

```powershell
# Verify the GroupPolicy module is available
Get-Module -ListAvailable -Name GroupPolicy

# Import the module (usually auto-imported)
Import-Module GroupPolicy
```

---

*Originally published on Shep's IT Solutions blog*
