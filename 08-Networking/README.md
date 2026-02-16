# Networking

Cisco network infrastructure configuration and administration.

## Contents

- [Cisco RADIUS Authentication with Active Directory and NPS](#cisco-radius-authentication-with-active-directory-and-nps)
- [Installing Cisco Fabric Manager on Windows 7 x64](#installing-cisco-fabric-manager-on-windows-7-x64)

---

## Cisco RADIUS Authentication with Active Directory and NPS

**Published:** 2014-08-27
**Tags:** AAA, RADIUS, Authentication, Cisco, SSH

Configure Cisco network devices (routers, switches, voice gateways) to authenticate against Active Directory using Windows Network Policy Server as a RADIUS server.

### Part 1: RADIUS Server Configuration

Assuming you already have a Network Policy Server installed on a DC...

**RADIUS Clients and Servers > RADIUS Clients > Right Click > New RADIUS Client**

- Add Friendly Name
- IP
- Vendor = Cisco
- Shared Secret
  - Manual
  - Enter a key (same as used on the Cisco device)

**Policies > Network Policies > Right Click > New** (use defaults unless specified)

- Policy Name (I just called this the same as the client friendly name)
- Conditions
  - Windows Groups: AD Group with network administrator accounts
  - Client Friendly Name: same as friendly from "RADIUS Clients" (prevents policies from inadvertently being applied to the wrong devices. Optional precaution)
- Authentication Methods > Check "Unencrypted authentication"
- "Configure Settings"
  - RADIUS Attributes
    - Standard > Remove Framed-Protocol PPP
    - Vendor Specific > Add (allows user to launch into enable mode by default)
      - Vendor = Cisco
      - Attribute Name = Cisco-AV-Pair
      - Value = `shell:priv-lvl=15`

### Part 2: SSH to Cisco Switch/Router

You'll need:
- VLAN/IP that authentication will originate from
- IP of your RADIUS Server
- RADIUS Secret used in part 1

Run the following from the command line:

```cisco
conf t
aaa new-model
aaa authentication login default group radius local
aaa authorization exec default group radius local
ip radius source-interface <<VLAN/IP>> Interface (e.g. Vlan1 or GigabitEthernet0/0)
radius-server host <<IP of RADIUS Server>> auth-port 1645 acct-port 1646
radius-server key <<RADIUS SECRET>>
service password-encryption
```

### Part 3: Testing

1. Ensure your admin account can log in
2. Ensure that other accounts cannot log in. Especially if you have other RADIUS auth policies like we did.
3. Validate that your local account no longer works by default.
4. "Disable" your RADIUS client. Validate that your local account works as a fail safe.

---

## Installing Cisco Fabric Manager on Windows 7 x64

**Published:** 2012-10-31
**Tags:** Cisco

### Prerequisites

1. **Download the latest version from the Cisco site**

   Cisco MDS 9000 Family Management Software and Documentation CD-ROM - Image for vX
   http://www.cisco.com/cisco/software/type.html?mdfid=282731430&catid=null

2. **Download Java RE 1.6**

   At the time of writing this the FM (4.2.9) software does not support Java RE 7.
   http://www.filehippo.com/download_jre_32/13491/

### Installation

3. Right click on Command Prompt > "Run as administrator"

4. Navigate to Java 1.6 installation:

   ```cmd
   cd "c:\Program Files (x86)\java\jre6\bin"
   ```

5. Run the installer JAR with elevated Java:

   ```cmd
   java.exe -Xmx512m -jar "C:\m9000-cd-4.2.9\software\m9000-fm-4.2.9.jar"
   ```

6. From there it's next - next - next.

---

*Originally published on Shep's IT Solutions blog*
