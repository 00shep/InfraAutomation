# System Center Configuration Manager (SCCM)

Configuration management and compliance monitoring for SCCM.

## Contents

- [Bitlocker Compliance Monitoring](#bitlocker-compliance-monitoring)

---

## Bitlocker Compliance Monitoring

**Published:** 2017-04-10  
**Tags:** SCCM, PowerShell, Bitlocker  
**Script:** [`Get-BitlockerComplianceStatus.ps1`](./Get-BitlockerComplianceStatus.ps1)

### Overview

After implementing Health Attestation in SCCM 1610 (which handled Windows 10 clients), we still needed to report on Bitlocker status for legacy clients to completely eliminate MBAM from our environment.

This compliance item queries for Bitlocker status on pre-Windows 10 clients.

### What the Script Does

1. Verifies that Bitlocker is enabled (ProtectionStatus = 1)
2. Verifies encryption cipher method is AES 256 (EncryptionMethod = 4)
3. Returns "Compliant" or "Non-Compliant"

### Encryption Method Values

| Value | Method |
|-------|--------|
| 0 | None |
| 1 | AES 128 with Diffuser |
| 2 | AES 256 with Diffuser |
| 3 | AES 128 (default) |
| 4 | AES 256 (desired) |

### Protection Status Values

| Value | Status |
|-------|--------|
| 0 | Protection disabled |
| 1 | Protection enabled |

### Creating the Compliance Item

1. **Create a new Configuration Item**
   - Type: Script
   - Name: Bitlocker Status Check

2. **Configure the Discovery Script**
   - Script type: PowerShell
   - Add the script content from [`Get-BitlockerComplianceStatus.ps1`](./Get-BitlockerComplianceStatus.ps1)

3. **Configure Compliance Rules**
   - Rule type: Value
   - Data type: String
   - Equals: "Compliant"

4. **Deploy to a Collection**
   - Create a Configuration Baseline
   - Add the Configuration Item
   - Deploy to your target collection

5. **Monitor Compliance**
   - View deployment status under Monitoring > Deployments
   - View individual client reports in the Compliance Details

### Troubleshooting

If you encounter issues with Health Attestation on Windows 10 clients, see this forum post:
https://social.technet.microsoft.com/Forums/en-US/359c1cb5-5bb0-42a2-9151-0e0b3d769bcd/missing-health-attestation-data-in-sccm?forum=ConfigMgrCompliance

---

*Originally published on Shep's IT Solutions blog*
