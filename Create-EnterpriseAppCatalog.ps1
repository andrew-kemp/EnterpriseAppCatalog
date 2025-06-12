function Read-Host-Default($prompt, $default) {
    $input = Read-Host "$prompt [$default]"
    if ([string]::IsNullOrWhiteSpace($input)) {
        return $default
    } else {
        return $input
    }
}

# --- Prompt for user-configurable settings ---
$Tenant = Read-Host-Default "Enter your tenant ID" "11016236-4dbc-43a6-8310-be803173fc43"
$TenantName = Read-Host-Default "Enter your tenant name (e.g. kempy)" "kempy"
$ClientId = Read-Host-Default "Enter your App/Client ID" "1525fc4b-5873-49e3-b0ca-aeb47fee4abd"
$CertificatePath = Read-Host-Default "Enter path to certificate (PFX)" "C:\certs\PnPAppCert.pfx"
$SiteTitle = Read-Host-Default "Enter the Site Title" "Enterprise Application Catalog"
$SiteShort = Read-Host-Default "Enter the Site short name (used in URL)" "EnterpriseApplicationCatalog10"
$OwnerEmail = Read-Host-Default "Enter the Site owner's email" "andrew@kemponline.co.uk"
$OtherOwnerEmail = "Luke.Skywalker@andykemp.com"

$SiteUrl = "https://$TenantName.sharepoint.com/sites/$SiteShort"
$AdminUrl = "https://$TenantName-admin.sharepoint.com"

Write-Host "Checking PowerShell version..."
$requiredVersion = [Version]"7.0.0"
$currentVersion = $PSVersionTable.PSVersion

if ($currentVersion -lt $requiredVersion) {
    Write-Host "PowerShell 7+ is required. Attempting to install via winget..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Microsoft.Powershell --source winget --accept-package-agreements --accept-source-agreements
        Write-Host "Please restart this script in PowerShell 7 (pwsh.exe) after installation."
        exit 1
    } else {
        Write-Warning "winget is not available. Please install PowerShell 7 manually from https://aka.ms/powershell"
        exit 1
    }
} else {
    Write-Host "PowerShell 7+ is present."
}

if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Host "PnP.PowerShell module not found. Installing..."
    Install-Module -Name PnP.PowerShell -Force -Scope CurrentUser
} else {
    Write-Host "PnP.PowerShell module found. Checking for updates..."
    try { Update-Module -Name PnP.PowerShell -Force -Scope CurrentUser } catch { }
}
Import-Module PnP.PowerShell

$SecureCertPassword = Read-Host "Enter certificate password" -AsSecureString

Connect-PnPOnline -Url $AdminUrl -ClientId $ClientId -Tenant $Tenant -CertificatePath $CertificatePath -CertificatePassword $SecureCertPassword

$site = Get-PnPTenantSite -Url $SiteUrl -ErrorAction SilentlyContinue
if (-not $site) {
    Write-Host "Creating site $SiteUrl..."
    New-PnPTenantSite -Title $SiteTitle `
        -Url $SiteUrl `
        -Owner $OwnerEmail `
        -TimeZone 2 `
        -Template "STS#3"
    $maxAttempts = 9
    $attempt = 1
    do {
        Start-Sleep -Seconds 20
        $site = Get-PnPTenantSite -Url $SiteUrl -ErrorAction SilentlyContinue
        $attempt++
    } while ((-not $site) -and ($attempt -le $maxAttempts))
    if (-not $site) {
        Write-Error "Site creation timed out. Exiting."
        Disconnect-PnPOnline
        exit 1
    }
    Write-Host "Site created and available."
} else {
    Write-Host "Site already exists: $SiteUrl"
}
Disconnect-PnPOnline

Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -Tenant $Tenant -CertificatePath $CertificatePath -CertificatePassword $SecureCertPassword

# --- List definitions (OSType instead of Type, and only use Title as the main name column) ---
$lists = @(
    @{Title="Application Catalog"; NameField="Application Name"; Fields=@(
        @{DisplayName="App Version"; InternalName="AppVersion"; Type="Text"},
        @{DisplayName="Business Owner"; InternalName="BusinessOwner"; Type="UserMulti"},
        @{DisplayName="Technical Owner"; InternalName="TechnicalOwner"; Type="UserMulti"},
        @{DisplayName="Department"; InternalName="Department"; Type="Lookup"; LookupList="Departments"},
        @{DisplayName="Hosting"; InternalName="Hosting"; Type="Choice"; Choices=@("On-Prem","Cloud","Hybrid")},
        @{DisplayName="Servers"; InternalName="Servers"; Type="LookupMulti"; LookupList="Servers"},
        @{DisplayName="SQL Databases"; InternalName="SQLDatabases"; Type="LookupMulti"; LookupList="SQL Databases"},
        @{DisplayName="Site"; InternalName="RelatedSite"; Type="Lookup"; LookupList="Sites"},
        @{DisplayName="Purpose"; InternalName="Purpose"; Type="Text"},
        @{DisplayName="Licensing"; InternalName="Licensing"; Type="Text"},
        @{DisplayName="Business Criticality"; InternalName="BusinessCriticality"; Type="Choice"; Choices=@("Platinum","Gold","Silver","Bronze")},
        @{DisplayName="Compliance Requirements"; InternalName="ComplianceRequirements"; Type="Text"},
        @{DisplayName="Migration Readiness"; InternalName="MigrationReadiness"; Type="Number"},
        @{DisplayName="6 R Classification"; InternalName="SixRClassification"; Type="Choice"; Choices=@("Rehost","Replatform","Refactor","Repurchase","Retire","Retain")},
        @{DisplayName="Support"; InternalName="Support"; Type="Text"},
        @{DisplayName="Authentication Method"; InternalName="AuthenticationMethod"; Type="Choice"; Choices=@("SSO","LDAP","OAuth","None")},
        @{DisplayName="Integration Points"; InternalName="IntegrationPoints"; Type="Text"},
        @{DisplayName="End of Life Date"; InternalName="EndOfLifeDate"; Type="DateTime"},
        @{DisplayName="Backup Strategy"; InternalName="BackupStrategy"; Type="Text"},
        @{DisplayName="Security Owner"; InternalName="SecurityOwner"; Type="UserMulti"},
        @{DisplayName="Discovery"; InternalName="Discovery"; Type="Choice"; Choices=@("Not started","In-Progress","Complete","Not Required")},
        @{DisplayName="Documentation"; InternalName="Documentation"; Type="URL"},
        @{DisplayName="Function/Role"; InternalName="FunctionRole"; Type="Text"}
    )},
    @{Title="Servers"; NameField="Server Name"; Fields=@(
        @{DisplayName="Operating System"; InternalName="ServerOperatingSystem"; Type="Lookup"; LookupList="Operating Systems"},
        @{DisplayName="Site"; InternalName="ServerSite"; Type="Lookup"; LookupList="Sites"},
        @{DisplayName="Department"; InternalName="ServerDepartment"; Type="Lookup"; LookupList="Departments"},
        @{DisplayName="Hardware Type"; InternalName="HardwareType"; Type="Choice"; Choices=@("Physical","Virtual")},
        @{DisplayName="Host Server"; InternalName="HostServer"; Type="Lookup"; LookupList="Servers"},
        @{DisplayName="CPU / RAM"; InternalName="CPURAM"; Type="Text"},
        @{DisplayName="Storage"; InternalName="Storage"; Type="Text"},
        @{DisplayName="IP Address"; InternalName="IPAddress"; Type="Text"},
        @{DisplayName="Purchase Date"; InternalName="PurchaseDate"; Type="DateTime"},
        @{DisplayName="In Support"; InternalName="InSupport"; Type="Boolean"},
        @{DisplayName="Owner"; InternalName="Owner"; Type="User"}
    )},
    @{Title="SQL Databases"; NameField="Database Name"; Fields=@(
        @{DisplayName="Database Server"; InternalName="DatabaseServer"; Type="LookupMulti"; LookupList="Servers"},
        @{DisplayName="DB Version"; InternalName="DBVersion"; Type="Text"},
        @{DisplayName="Size"; InternalName="Size"; Type="Number"},
        @{DisplayName="Owner"; InternalName="DatabaseOwner"; Type="User"},
        @{DisplayName="In Use"; InternalName="InUse"; Type="Boolean"},
        @{DisplayName="Backup Enabled"; InternalName="BackupEnabled"; Type="Boolean"},
        @{DisplayName="Last Backup Date"; InternalName="LastBackupDate"; Type="DateTime"}
    )},
    @{Title="Operating Systems"; NameField="OS Name"; Fields=@(
        @{DisplayName="OS Version"; InternalName="OSVersion"; Type="Text"},
        @{DisplayName="Edition"; InternalName="Edition"; Type="Text"},
        @{DisplayName="Vendor"; InternalName="Vendor"; Type="Text"},
        @{DisplayName="Support Status"; InternalName="SupportStatus"; Type="Text"},
        @{DisplayName="OS Type"; InternalName="OSType"; Type="Choice"; Choices=@("Operating System","Hypervisor")}
    )},
    @{Title="Sites"; NameField="Site Name"; Fields=@(
        @{DisplayName="Location"; InternalName="Location"; Type="Text"},
        @{DisplayName="Region"; InternalName="Region"; Type="Text"},
        @{DisplayName="Site Type"; InternalName="SiteType"; Type="Choice"; Choices=@("Data Center","Office","Cloud Region")}
    )},
    @{Title="Departments"; NameField="Department Name"; Fields=@(
        @{DisplayName="Cost Center"; InternalName="CostCenter"; Type="Text"},
        @{DisplayName="Manager"; InternalName="Manager"; Type="User"}
    )}
)

# --- Create lists and rename Title fields ---
foreach ($list in $lists) {
    $listTitle = $list.Title
    $nameField = $list.NameField
    if (-not (Get-PnPList -Identity $listTitle -ErrorAction SilentlyContinue)) {
        Write-Host "Creating list: $listTitle"
        New-PnPList -Title $listTitle -Template GenericList -OnQuickLaunch
    } else {
        Write-Host "List exists: $listTitle"
    }
    # Correct way to rename the 'Title' field's display name
    Set-PnPField -List $listTitle -Identity "Title" -Values @{Title = $nameField}
}

# --- Add all non-lookup fields first, then add lookup fields (supporting multi-value user fields) ---
foreach ($list in $lists) {
    $listTitle = $list.Title
    foreach ($field in $list.Fields) {
        $existingField = Get-PnPField -List $listTitle -Identity $field.InternalName -ErrorAction SilentlyContinue
        if (-not $existingField) {
            if ($field.Type -eq "Lookup" -or $field.Type -eq "LookupMulti") {
                continue # Defer lookups until all lists/fields are created
            }
            elseif ($field.Type -eq "Choice" -or $field.Type -eq "MultiChoice") {
                $params = @{
                    List = $listTitle
                    DisplayName = $field.DisplayName
                    InternalName = $field.InternalName
                    Type = "Choice"
                    Choices = $field.Choices
                }
                if ($field.ContainsKey("Required")) { $params.Add("Required", $field.Required) }
                Add-PnPField @params
            }
            elseif ($field.Type -eq "UserMulti") {
                $fieldXml = "<Field Type='UserMulti' DisplayName='$($field.DisplayName)' StaticName='$($field.InternalName)' Name='$($field.InternalName)' Mult='TRUE' UserSelectionMode='PeopleAndGroups' />"
                Add-PnPFieldFromXml -List $listTitle -FieldXml $fieldXml
            }
            else {
                $params = @{
                    List = $listTitle
                    DisplayName = $field.DisplayName
                    InternalName = $field.InternalName
                    Type = $field.Type
                }
                if ($field.ContainsKey("Required")) { $params.Add("Required", $field.Required) }
                Add-PnPField @params
            }
        }
    }
}

# --- Remove and recreate specific multi-value lookup fields (Servers, Database Server) ---
Remove-PnPField -List "Application Catalog" -Identity "Servers" -Force -ErrorAction SilentlyContinue
Remove-PnPField -List "SQL Databases" -Identity "DatabaseServer" -Force -ErrorAction SilentlyContinue

# Get Servers list ID
$serversList = Get-PnPList -Identity "Servers"
$serversListId = $serversList.Id

# Add multi-value lookup for Servers in Application Catalog
$fieldXml = "<Field Type='LookupMulti' DisplayName='Servers' StaticName='Servers' Name='Servers' List='{$serversListId}' ShowField='Title' Mult='TRUE' />"
Add-PnPFieldFromXml -List "Application Catalog" -FieldXml $fieldXml

# Add multi-value lookup for Database Server in SQL Databases
$fieldXml = "<Field Type='LookupMulti' DisplayName='Database Server' StaticName='DatabaseServer' Name='DatabaseServer' List='{$serversListId}' ShowField='Title' Mult='TRUE' />"
Add-PnPFieldFromXml -List "SQL Databases" -FieldXml $fieldXml

# --- Now add other Lookup and LookupMulti fields ---
foreach ($list in $lists) {
    $listTitle = $list.Title
    foreach ($field in $list.Fields) {
        if ($field.Type -eq "Lookup" -or $field.Type -eq "LookupMulti") {
            if (($field.InternalName -eq "Servers" -and $listTitle -eq "Application Catalog") -or
                ($field.InternalName -eq "DatabaseServer" -and $listTitle -eq "SQL Databases")) {
                continue # Already handled above
            }
            $existingField = Get-PnPField -List $listTitle -Identity $field.InternalName -ErrorAction SilentlyContinue
            if (-not $existingField) {
                $lookupTargetList = Get-PnPList -Identity $field.LookupList
                $lookupListId = $lookupTargetList.Id
                $typeString = if ($field.Type -eq "LookupMulti") { "LookupMulti" } else { "Lookup" }
                $multiAttr = if ($field.Type -eq "LookupMulti") { " Mult='TRUE'" } else { "" }
                $showField = "Title"
                $required = if ($field.ContainsKey("Required") -and $field.Required) { "TRUE" } else { "FALSE" }
                $fieldXml = "<Field Type='$typeString' DisplayName='$($field.DisplayName)' StaticName='$($field.InternalName)' Name='$($field.InternalName)' List='{$lookupListId}' ShowField='$showField' Required='$required'$multiAttr />"
                Add-PnPFieldFromXml -List $listTitle -FieldXml $fieldXml
            }
        }
    }
}

# --- Add a "Full Columns" view for each list and set as default ---
foreach ($list in $lists) {
    $listTitle = $list.Title
    $fields = (Get-PnPField -List $listTitle | Where-Object { $_.Hidden -eq $false -and $_.ReadOnlyField -eq $false }).InternalName
    try { Remove-PnPView -List $listTitle -Identity "Full Columns" -Force -ErrorAction SilentlyContinue } catch {}
    Add-PnPView -List $listTitle -Title "Full Columns" -Fields $fields -SetAsDefault
}

# --- Departments: hard-coded, no CSV option ---
$departmentsAdded = @()
$departmentsAdded += Add-PnPListItem -List "Departments" -Values @{"Title"="IT"; "CostCenter"="1001"; "Manager"=$OwnerEmail}
$departmentsAdded += Add-PnPListItem -List "Departments" -Values @{"Title"="Finance"; "CostCenter"="1002"; "Manager"=$OwnerEmail}

function Get-DeptId($name) {
    $dept = $departmentsAdded | Where-Object { $_.FieldValues.Title -eq $name }
    return $dept.Id
}

# --- Ensure the OSType field exists for Operating Systems and robustly wait until SharePoint confirms it is present ---
$maxWait = 30
$waited = 0
$osTypeField = Get-PnPField -List "Operating Systems" -Identity "OSType" -ErrorAction SilentlyContinue
if (-not $osTypeField) {
    Write-Host "Creating the 'OS Type' column on Operating Systems list..."
    Add-PnPField -List "Operating Systems" -DisplayName "OS Type" -InternalName "OSType" -Type Choice -Choices @("Operating System", "Hypervisor")
}
do {
    Start-Sleep -Seconds 2
    $waited += 2
    $osTypeField = Get-PnPField -List "Operating Systems" -Identity "OSType" -ErrorAction SilentlyContinue
    Write-Host "Waiting for SharePoint to register the 'OS Type' column... ($waited sec)"
} while ((-not $osTypeField) -and ($waited -lt $maxWait))
if (-not $osTypeField) {
    throw "The 'OS Type' column did not appear in the Operating Systems list after $maxWait seconds."
}

# --- Bulk add Operating Systems and Hypervisors to the "Operating Systems" list ---
$OperatingSystems = @(
    @{ Title="Windows Server 2022 Standard";    OSVersion="2022";      Edition="Standard";        Vendor="Microsoft";  SupportStatus="Mainstream support until Oct 13, 2026; Extended until Oct 14, 2031"; OSType="Operating System" },
    @{ Title="Windows Server 2022 Datacenter";  OSVersion="2022";      Edition="Datacenter";      Vendor="Microsoft";  SupportStatus="Mainstream support until Oct 13, 2026; Extended until Oct 14, 2031"; OSType="Operating System" },
    @{ Title="Windows Server 2019 Standard";    OSVersion="2019";      Edition="Standard";        Vendor="Microsoft";  SupportStatus="Mainstream support ended, Extended support until Jan 9, 2029"; OSType="Operating System" },
    @{ Title="Windows Server 2019 Datacenter";  OSVersion="2019";      Edition="Datacenter";      Vendor="Microsoft";  SupportStatus="Mainstream support ended, Extended support until Jan 9, 2029"; OSType="Operating System" },
    @{ Title="Windows Server 2019 Essentials";  OSVersion="2019";      Edition="Essentials";      Vendor="Microsoft";  SupportStatus="Mainstream support ended, Extended support until Jan 9, 2029"; OSType="Operating System" },
    @{ Title="Windows Server 2016 Standard";    OSVersion="2016";      Edition="Standard";        Vendor="Microsoft";  SupportStatus="Extended support until Jan 12, 2027"; OSType="Operating System" },
    @{ Title="Windows Server 2016 Datacenter";  OSVersion="2016";      Edition="Datacenter";      Vendor="Microsoft";  SupportStatus="Extended support until Jan 12, 2027"; OSType="Operating System" },
    @{ Title="Windows Server 2012 R2 Standard"; OSVersion="2012 R2";   Edition="Standard";        Vendor="Microsoft";  SupportStatus="Extended support ended Oct 10, 2023"; OSType="Operating System" },
    @{ Title="Windows Server 2012 R2 Datacenter"; OSVersion="2012 R2"; Edition="Datacenter";      Vendor="Microsoft";  SupportStatus="Extended support ended Oct 10, 2023"; OSType="Operating System" },
    # Linux - Ubuntu
    @{ Title="Ubuntu 22.04 LTS";               OSVersion="22.04 LTS"; Edition="LTS";             Vendor="Canonical";   SupportStatus="Standard support until April 2027 (ESM until April 2032)"; OSType="Operating System" },
    @{ Title="Ubuntu 20.04 LTS";               OSVersion="20.04 LTS"; Edition="LTS";             Vendor="Canonical";   SupportStatus="Standard support until April 2025 (ESM until April 2030)"; OSType="Operating System" },
    @{ Title="Ubuntu 18.04 LTS";               OSVersion="18.04 LTS"; Edition="LTS";             Vendor="Canonical";   SupportStatus="Standard support ended May 2023 (ESM until April 2028)"; OSType="Operating System" },
    # Linux - Red Hat
    @{ Title="Red Hat Enterprise Linux 9";      OSVersion="9";         Edition="Enterprise";      Vendor="Red Hat";     SupportStatus="Full support until May 2027"; OSType="Operating System" },
    @{ Title="Red Hat Enterprise Linux 8";      OSVersion="8";         Edition="Enterprise";      Vendor="Red Hat";     SupportStatus="Full support until May 2029"; OSType="Operating System" },
    @{ Title="Red Hat Enterprise Linux 7";      OSVersion="7";         Edition="Enterprise";      Vendor="Red Hat";     SupportStatus="Maintenance support until June 2024"; OSType="Operating System" },
    # Linux - CentOS
    @{ Title="CentOS 7";                        OSVersion="7";         Edition="Server";          Vendor="CentOS Project"; SupportStatus="Maintenance support until June 30, 2024"; OSType="Operating System" },
    # Linux - SUSE
    @{ Title="SUSE Linux Enterprise Server 15"; OSVersion="15";        Edition="Server";          Vendor="SUSE";        SupportStatus="General support until July 31, 2028"; OSType="Operating System" },
    # Hypervisors
    @{ Title="VMware ESXi 7.0";                 OSVersion="7.0";       Edition="Enterprise Plus"; Vendor="VMware";      SupportStatus="General support until April 2, 2025"; OSType="Hypervisor" },
    @{ Title="VMware ESXi 8.0";                 OSVersion="8.0";       Edition="Enterprise Plus"; Vendor="VMware";      SupportStatus="General support until October 15, 2027"; OSType="Hypervisor" },
    @{ Title="Windows Server 2022 Hyper-V";     OSVersion="2022";      Edition="Standard/Datacenter"; Vendor="Microsoft"; SupportStatus="Mainstream support until Oct 13, 2026; Extended until Oct 14, 2031"; OSType="Hypervisor" },
    @{ Title="Windows Server 2019 Hyper-V";     OSVersion="2019";      Edition="Standard/Datacenter"; Vendor="Microsoft"; SupportStatus="Mainstream support ended, Extended support until Jan 9, 2029"; OSType="Hypervisor" }
)

$osRef = @{}
foreach ($os in $OperatingSystems) {
    $osRef[$os.Title] = Add-PnPListItem -List "Operating Systems" -Values @{
        "Title" = $os.Title
        "OSVersion" = $os.OSVersion
        "Edition" = $os.Edition
        "Vendor" = $os.Vendor
        "SupportStatus" = $os.SupportStatus
        "OSType" = $os.OSType
    }
}

# Pick two OSs for the server sample data
$osWin = $osRef["Windows Server 2019 Standard"]
$osUbu = $osRef["Ubuntu 20.04 LTS"]

$siteDCA = Add-PnPListItem -List "Sites" -Values @{"Title"="Data Center A"; "Location"="New York"; "Region"="North America"; "SiteType"="Data Center"}
$siteLon = Add-PnPListItem -List "Sites" -Values @{"Title"="London Office"; "Location"="London"; "Region"="Europe"; "SiteType"="Office"}

# Fallback for Departments if not imported above
$deptITId = Get-DeptId "IT"
$deptFinId = Get-DeptId "Finance"

# --- Add Host/Physical/Virtual Servers ---
# A physical host server
$serverHost = Add-PnPListItem -List "Servers" -Values @{
    "Title"="HostServer1";
    "ServerOperatingSystem"=$osWin.Id;
    "ServerSite"=$siteDCA.Id;
    "ServerDepartment"=$deptITId;
    "HardwareType"="Physical";
    "CPURAM"="16 vCPU / 64 GB";
    "Storage"="2 TB SSD";
    "IPAddress"="192.168.1.10";
    "PurchaseDate"="2019-11-01";
    "InSupport"=$true;
    "Owner"=$OwnerEmail
}

# A physical server
$server1 = Add-PnPListItem -List "Servers" -Values @{
    "Title"="Server1";
    "ServerOperatingSystem"=$osWin.Id;
    "ServerSite"=$siteDCA.Id;
    "ServerDepartment"=$deptITId;
    "HardwareType"="Physical";
    "CPURAM"="8 vCPU / 32 GB";
    "Storage"="1 TB SSD";
    "IPAddress"="192.168.1.1";
    "PurchaseDate"="2020-01-01";
    "InSupport"=$true;
    "Owner"=$OwnerEmail
}

# A virtual server, hosted on HostServer1
$server2 = Add-PnPListItem -List "Servers" -Values @{
    "Title"="Server2";
    "ServerOperatingSystem"=$osUbu.Id;
    "ServerSite"=$siteLon.Id;
    "ServerDepartment"=$deptFinId;
    "HardwareType"="Virtual";
    "HostServer"=$serverHost.Id;
    "CPURAM"="4 vCPU / 16 GB";
    "Storage"="500 GB SSD";
    "IPAddress"="192.168.1.2";
    "PurchaseDate"="2021-06-15";
    "InSupport"=$true;
    "Owner"=$OwnerEmail
}

$db1 = Add-PnPListItem -List "SQL Databases" -Values @{
    "Title"="DB1";
    "DatabaseServer"=@($server1.Id, $server2.Id); # Multi-value
    "DBVersion"="SQL Server 2019";
    "Size"=100;
    "DatabaseOwner"=$OwnerEmail;
    "InUse"=$true;
    "BackupEnabled"=$true;
    "LastBackupDate"="2023-01-01"
}
$db2 = Add-PnPListItem -List "SQL Databases" -Values @{
    "Title"="DB2";
    "DatabaseServer"=@($server2.Id); # Multi-value
    "DBVersion"="MySQL 8.0";
    "Size"=50;
    "DatabaseOwner"=$OwnerEmail;
    "InUse"=$true;
    "BackupEnabled"=$true;
    "LastBackupDate"="2023-01-01"
}

Add-PnPListItem -List "Application Catalog" -Values @{
    "Title"="App1";
    "AppVersion"="1.0";
    "BusinessOwner"=@($OwnerEmail, $OtherOwnerEmail);
    "TechnicalOwner"=@($OwnerEmail);
    "Department"=$deptITId;
    "Hosting"="On-Prem";
    "Servers"=@($server1.Id, $server2.Id); # Multi-value
    "SQLDatabases"=@($db1.Id, $db2.Id); # Multi-value
    "RelatedSite"=$siteDCA.Id;
    "Purpose"="Finance Management";
    "Licensing"="Perpetual";
    "BusinessCriticality"="Platinum";
    "ComplianceRequirements"="GDPR";
    "MigrationReadiness"=80;
    "SixRClassification"="Rehost";
    "Support"="24/7";
    "AuthenticationMethod"="SSO";
    "IntegrationPoints"="None";
    "EndOfLifeDate"="2025-12-31";
    "BackupStrategy"="Daily";
    "SecurityOwner"=@($OwnerEmail);
    "Discovery"="In-Progress";
    # "Documentation" omitted
    "FunctionRole"="Financial Processing"
}
Add-PnPListItem -List "Application Catalog" -Values @{
    "Title"="App2";
    "AppVersion"="2.0";
    "BusinessOwner"=@($OwnerEmail);
    "TechnicalOwner"=@($OwnerEmail, $OtherOwnerEmail);
    "Department"=$deptFinId;
    "Hosting"="Cloud";
    "Servers"=@($server2.Id); # Multi-value
    "SQLDatabases"=@($db2.Id); # Multi-value
    "RelatedSite"=$siteLon.Id;
    "Purpose"="HR Management";
    "Licensing"="Subscription";
    "BusinessCriticality"="Gold";
    "ComplianceRequirements"="HIPAA";
    "MigrationReadiness"=60;
    "SixRClassification"="Replatform";
    "Support"="Business Hours";
    "AuthenticationMethod"="OAuth";
    "IntegrationPoints"="None";
    "EndOfLifeDate"="2024-06-30";
    "BackupStrategy"="Weekly";
    "SecurityOwner"=@($OwnerEmail, $OtherOwnerEmail);
    "Discovery"="Not started";
    # "Documentation" omitted
    "FunctionRole"="HR System"
}

Write-Host "`nProvisioning complete! All columns and sample data created, including pre-filled Operating Systems, Hypervisors, servers (with host/virtual/physical logic), and a 'Full Columns' view is set as default for each list."
