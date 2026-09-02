# Infrastructure Automation Scripts

A collection of PowerShell scripts and guides for Windows infrastructure management, migrated from **Shep's IT Solutions** blog (2011-2021).

## 📁 Repository Structure

| Folder | Topic | Scripts | Description |
|--------|-------|---------|-------------|
| **[01-ActiveDirectory](./01-ActiveDirectory/)** | Active Directory | 7 | Bulk operations, LDAP queries, maintenance scripts |
| **[03-SCOM](./03-SCOM/)** | System Center Operations Manager | 1 | Troubleshooting fSMORoleOwner alerts |
| **[04-SCCM](./04-SCCM/)** | System Center Configuration Manager | 1 | Bitlocker compliance monitoring |
| **[06-Azure](./06-Azure/)** | Azure Management | 1 | ASR recovery plan audit script |
| **[07-GroupPolicy](./07-GroupPolicy/)** | Group Policy | 2 | GPO auditing and cleanup |
| **[08-UltiPro](./08-UltiPro/)** | UltiPro/UKG Pro Integration | 2 | HR to AD sync (REST & RaaS) |

---

## 🎯 Quick Navigation by Task

### Active Directory Administration

**Bulk Operations:**
- [Bulk Update Home Folder Paths](./01-ActiveDirectory/README.md#bulk-update-home-folder-paths) - Change home drive mappings for users
- [Bulk Update Logon Scripts](./01-ActiveDirectory/README.md#bulk-update-logon-scripts) - Update script paths for OUs
- [Bulk Update User UPNs](./01-ActiveDirectory/README.md#bulk-update-user-upns) - Change UPN suffixes for migrations

**Queries & Searches:**
- [Find Inactive Computer Objects](./01-ActiveDirectory/README.md#find-inactive-computer-objects) - Identify stale computer accounts
- [Find Users with Specific UPN Suffix](./01-ActiveDirectory/README.md#find-users-with-specific-upn-suffix) - Audit UPN assignments
- [Find Servers Not in a Group](./01-ActiveDirectory/README.md#find-servers-not-in-a-group-ldap-query) - LDAP query with recursive group checking

**Maintenance:**
- [Find Orphaned Home Drives](./01-ActiveDirectory/README.md#find-orphaned-home-drives) - Identify folders for deleted accounts with size reports

### System Center Operations Manager (SCOM)

- [OpsMgr Active Directory fSMORoleOwner Alerts](./03-SCOM/README.md#opsmgr-active-directory-fsmoroleowner-alerts) - Fix fSMO inconsistencies after DC demotion

### System Center Configuration Manager (SCCM)

- [Bitlocker Compliance Monitoring](./04-SCCM/README.md#bitlocker-compliance-monitoring) - Report on Bitlocker status for pre-Windows 10 clients

### Azure Administration

- [Azure Site Recovery - Recovery Plan Audit](./06-Azure/README.md#azure-site-recovery---recovery-plan-audit) - Identify replicated items missing recovery plan assignments

### Group Policy Management

- [Find GPOs with No Links](./07-GroupPolicy/README.md#find-gpos-with-no-links) - Identify unlinked GPOs for cleanup
- [Find GPOs with Disabled Links](./07-GroupPolicy/README.md#find-gpos-with-disabled-links) - Find GPOs with all links disabled

### HR System Integration

**UltiPro/UKG Pro to Active Directory Sync:**
- [REST API Method (CSV)](./08-UltiPro/README.md#rest-api-method-csv-export) - Standard REST API approach with CSV export
- [Report-as-a-Service Method (SQL)](./08-UltiPro/README.md#report-as-a-service-method-sql-import) - Faster SOAP-based method with SQL import

---

## 🔧 Common Use Cases

### Domain Migrations & Consolidations
- [Bulk Update User UPNs](./01-ActiveDirectory/README.md#bulk-update-user-upns)
- [Find Users with Specific UPN Suffix](./01-ActiveDirectory/README.md#find-users-with-specific-upn-suffix)
- [Bulk Update Home Folder Paths](./01-ActiveDirectory/README.md#bulk-update-home-folder-paths)

### Active Directory Cleanup
- [Find Inactive Computer Objects](./01-ActiveDirectory/README.md#find-inactive-computer-objects)
- [Find Orphaned Home Drives](./01-ActiveDirectory/README.md#find-orphaned-home-drives)
- [Find GPOs with No Links](./07-GroupPolicy/README.md#find-gpos-with-no-links)

### Compliance & Auditing
- [Bitlocker Compliance Monitoring](./04-SCCM/README.md#bitlocker-compliance-monitoring)
- [Azure Site Recovery Audit](./06-Azure/README.md#azure-site-recovery---recovery-plan-audit)
- [Find Servers Not in a Group](./01-ActiveDirectory/README.md#find-servers-not-in-a-group-ldap-query)

### HR Data Synchronization
- [UltiPro/UKG Pro Integration](./08-UltiPro/README.md) - Two methods for syncing employee data to AD

---

## 📋 Script Features

All scripts in this repository share common characteristics:

✅ **Well-Documented** - Comprehensive help blocks with examples  
✅ **PowerShell Best Practices** - Proper error handling and parameter validation  
✅ **Production-Tested** - Used in real enterprise environments  
✅ **Modular Design** - Easy to adapt to your environment  

### Script Headers

Each PowerShell script includes:
- **Synopsis** - One-line description
- **Description** - Detailed functionality explanation
- **Parameters** - Input parameter documentation
- **Examples** - Usage examples
- **Notes** - Author, date, special considerations

### README Structure

Each folder's README includes:
- **Overview** - What the scripts do
- **Prerequisites** - Required modules, permissions
- **Usage Examples** - How to run the scripts
- **Technical Notes** - Implementation details
- **Troubleshooting** - Common issues and solutions

---

## 🚀 Getting Started

### Prerequisites

Most scripts require:
- **Windows PowerShell 5.1+** or **PowerShell 7+**
- **Active Directory Module** (`RSAT-AD-PowerShell`)
- **Appropriate Permissions** - Domain Admin for bulk operations, read-only for queries

### Installation

```powershell
# Install Active Directory module (Windows 10/11)
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Install Active Directory module (Windows Server)
Install-WindowsFeature -Name RSAT-AD-PowerShell

# For GroupPolicy scripts
Install-WindowsFeature -Name GPMC
```

### Running a Script

```powershell
# 1. Navigate to the script folder
cd 01-ActiveDirectory

# 2. Review the README
Get-Content README.md

# 3. Read the script help
Get-Help .\Find-OrphanedHomeDrives.ps1 -Full

# 4. Run with parameters
.\Find-OrphanedHomeDrives.ps1 -HomeDrivePath "\\fileserver\home$" -OutputFile "C:\Reports\orphaned.csv"
```

---

## ⚠️ Important Notes

### Testing Recommendations

1. **Test in Non-Production First** - Always validate scripts in a dev/test environment
2. **Review Before Bulk Operations** - Understand what will change before executing
3. **Backup Critical Data** - Take AD snapshots before bulk modifications
4. **Start Small** - Test on a small subset before processing thousands of objects

### API-Based Scripts

Some scripts interact with external APIs:

**UltiPro/UKG Pro:**
- ⚠️ **Authentication Updated** - UKG Pro now uses OAuth 2.0 (see [migration notes](./08-UltiPro/README.md#api-migration-notes))
- 📚 **Documentation** - Official docs at [developer.ukg.com](https://developer.ukg.com)

**Azure:**
- 🔑 Requires Azure PowerShell module (`Az.RecoveryServices`)
- 🔐 Requires appropriate Azure RBAC permissions

### Deprecated Technologies

Some scripts reference older technologies that may no longer be relevant:

- **SCOM 2012** - Concepts still apply to modern SCOM versions
- **SCCM 1610** - Now called Configuration Manager (Current Branch)
- **MBAM** - Microsoft BitLocker Administration and Monitoring (deprecated)

---

## 📚 Additional Resources

### Microsoft Documentation

- [Active Directory Administration with PowerShell](https://docs.microsoft.com/en-us/powershell/module/activedirectory/)
- [Group Policy Management](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn265969(v=ws.11))
- [System Center Configuration Manager](https://docs.microsoft.com/en-us/mem/configmgr/)
- [Azure Site Recovery](https://docs.microsoft.com/en-us/azure/site-recovery/)

### Community Resources

- [PowerShell Gallery](https://www.powershellgallery.com/)
- [TechNet Script Center](https://gallery.technet.microsoft.com/scriptcenter)
- [Reddit /r/PowerShell](https://www.reddit.com/r/PowerShell/)

---

## 📝 License & Attribution

These scripts were originally published on **Shep's IT Solutions** blog between 2011 and 2021. They are provided as-is for educational and professional use.

**Author:** 00Shep  
**Original Blog:** https://00shep.blogspot.com/ (archived content migrated here)  
**Repository:** https://github.com/00shep/InfraAutomation

---

## 🤝 Contributing

Found a bug or have an improvement? Feel free to:

1. Open an issue describing the problem or enhancement
2. Submit a pull request with your changes
3. Share your experience using these scripts

---

## 📞 Support

These scripts are provided as community contributions without official support. For issues:

1. Check the script's README for troubleshooting tips
2. Review the PowerShell help: `Get-Help <script> -Full`
3. Search for similar issues in the community
4. Open an issue in this repository

---

**Last Updated:** 2026  
**Original Publication Period:** 2011-2021
