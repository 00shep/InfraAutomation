# System Center Operations Manager (SCOM)

Troubleshooting guides and configuration tips for SCOM/OpsMgr.

## Contents

- [OpsMgr Active Directory fSMORoleOwner Alerts](#opsmgr-active-directory-fsmoroleowner-alerts)

---

## OpsMgr Active Directory fSMORoleOwner Alerts

**Published:** 2011-12-06  
**Tags:** SCOM, OpsMgr, Active Directory

### Overview

This guide covers fixing Active Directory fSMORoleOwner inconsistencies detected by System Center Operations Manager 2007 R2. The actual change takes about 5 minutes — the research and planning took all the time.

### The Problem

We recently identified a problem through SCOM with our Active Directory environment. After forcibly demoting our primary domain controller, traces of the old configuration remained.

**SCOM Error:**
```
AD Replication Partner Op Master Consistency: The script 'AD Replication Partner Op Master Consistency' 
failed to execute the following LDAP query: '<LDAP://DC3.MYDOMAIN.com/CN=Configuration,DC=MYDOMAIN,DC=com>;
(&(objectClass=crossRefContainer)(fSMORoleOwner=*));fSMORoleOwner;Subtree'. 
The error returned was 'The server is not operational.' (0x80040E37)
```

**Root Cause:**  
The fSMORoleOwner in ForestDNSZones and DomainDNSZones were both different and neither were correct. It should have been set to DC1, but:
- ForestDNSZone showed DC2 (a current DC)
- DomainDNSZone showed OLD-DC1 (decommissioned)

### Checking Your System

Add these namespaces to ADSI Edit:

1. **Configuration**
2. **DC=DomainDNSZones,DC=MyDOMAIN,DC=COM**
3. **DC=ForestDNSZones,DC=MyDOMAIN,DC=COM**

The fix: Copy the settings from the **distinguishedName** attribute under **Configuration** in ADSI Edit for the correct **fSMORoleOwner**. Update the owner attribute under **DomainDNSZones** and **ForestDNSZones**.

### The Gotchas

1. **Must be done on the actual infrastructure master**
2. **Formatting matters:**
   - Read in several places to copy the distinguished name
   - That value is in a different format than the fSMORoleOwner property
   - Grab a copy of the existing fSMORoleOwner value for two reasons:
     - a. Copy the proper formatting
     - b. Revert if needed (unlikely)
3. **CN=Infrastructure location:**
   - CN=Infrastructure is at the root of the Domain/ForestDNSZones
   - If you just expanded that container you wouldn't see it

### Format Examples

**distinguishedName example:**
```
CN=DC1,CN=Servers,CN=Site1,CN=Sites,CN=Configuration,DC=MyDOMAIN,DC=com
```

**fSMORoleOwner example:**
```
CN=NTDS Settings,CN=DC1,CN=Servers,CN=Site1,CN=Sites,CN=Configuration,DC=MyDOMAIN,DC=com
```

### Additional Considerations

1. **Anti-virus:** Some people pointed to AV issues. In our environment this was NOT the issue. OpsMgr was right on the money.

2. **Metadata cleanup:** Definitely something anyone should do in this situation. However, we found that the metadata was actually removed properly. Don't assume the cleanup will fix the issue — it's just good advice and best practice.

3. **fixfsmo.vbs script:** There is a script that will do the same. I didn't use it because it was just as easy to update manually. The script is basic: checks current, checks what it should be, updates if it doesn't match.

---

## CHECKLIST

### Phase 1 - fSMO Cleanup

1. **Perform AD Backup** (system state and system drive) using NTBACKUP.exe
2. **Turn off extra domain controller** (if available)
   - This was a great idea from my supervisor
   - If anything went wrong we could make it look like this DC had the latest version and replicate back to others
   - Update fSMORoleOwner in forestDNSZones and domainDNSZones
3. **TEST!**
   - Confirm logging in on all DCs works, VPN, etc.
   - If no issues, power on the extra DC
4. **Validate replication** using `repadmin /replsum` (I had to force replication to the DC that was powered off)
5. **Confirm that OpsMgr errors go away**

### Phase 2 - DC Metadata Cleanup

1. **Repeat backup process**
2. **Run cleanup utility**

   **Scripted Method:**  
   http://gallery.technet.microsoft.com/d31f091f-2642-4ede-9f97-0e1cc4d577f3

   **Manual Method from command prompt:**
   ```cmd
   Ntdsutil.exe
   Ntdsutil.exe: metadata cleanup
   metadata cleanup: remove selected server <server name>
   ```

3. **Repeat testing**

---

## Resources

Here are valuable resources referenced during this process:

- http://social.technet.microsoft.com/Forums/sr-Latn-CS/winserverDS/thread/95c78db6-f53a-48c7-84c9-3c57cd683e4c
- http://forums.techarena.in/active-directory/1143475.htm
- http://social.technet.microsoft.com/Forums/sr-Latn-CS/winserverDS/thread/0b956901-930c-4fe7-80ad-939de1f61b48
- http://technet.microsoft.com/en-us/library/bb727048.aspx
- http://technet.microsoft.com/en-us/library/cc731035%28WS.10%29.aspx
- http://support.microsoft.com/kb/949257

---

## Conclusion

In the end there were no reboots required, no downtime, nothing like that. But there's something to be said for peace of mind after having all of the necessary information.

---

*Originally published on Shep's IT Solutions blog*
