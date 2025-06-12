# Enterprise Application Catalog Provisioning Scripts

This repository contains two PowerShell scripts to automate the setup of a SharePoint Online "Enterprise Application Catalog" using PnP PowerShell and certificate-based authentication.

## Contents

- **Create-Cert.ps1**: Generates a self-signed certificate for use with Azure AD App Registration and SharePoint PnP authentication.
- **Create-EnterpriseAppCatalog.ps1**: Provisions a new SharePoint site and all required lists, columns, views, and sample data for the Enterprise Application Catalog.

---

## What This Does

- **Automates the creation of a SharePoint Online site** (or connects to an existing one) for cataloging business applications.
- **Creates lists**: Application Catalog, Servers, SQL Databases, Operating Systems, Sites, Departments.
- **Adds all required columns** (including lookups, people fields, multi-choice, and rich metadata).
- **Populates lists with sample data** for operating systems, servers, SQL databases, and applications.
- **Sets up a "Full Columns" view** for each list.
- **Handles all dependencies between lists and columns** (including multi-value lookups and people fields).
- **Requires no manual SharePoint configuration**—all is handled via script.

---

## Prerequisites

1. **PowerShell 7+** (the script will auto-detect and prompt for installation if needed).
2. **PnP.PowerShell module** (the script will install or update as required).
3. **Azure AD App Registration** with permissions to SharePoint (see below).
4. **SharePoint Online Admin permissions**.

---

## 1. Creating the Certificate

Run **Create-Cert.ps1** first to generate a self-signed certificate (PFX and CER files):

```powershell
.\Create-Cert.ps1
```

- This creates a certificate in `C:\certs` by default, named `PnPAppCert.pfx` and `PnPAppCert.cer`.
- **IMPORTANT:** Change the `$pfxPassword` variable to a strong password before use.
- The `.pfx` file is used for authentication; the `.cer` file will be uploaded to Azure AD.

---

## 2. Registering the Azure AD App (Enterprise App)

### **Manual Steps in Azure Portal**

1. **Go to** [Azure Portal > Azure Active Directory > App registrations](https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredApps).
2. **New registration**:  
   - Name: `EnterpriseAppCatalog` (or as desired)
   - Supported account types: Single tenant (default)
   - Redirect URI: Leave blank for now

3. **After registration:**
   - **Application (client) ID**: Note this value for `$ClientId`.
   - **Directory (tenant) ID**: Note this for `$Tenant`.

4. **Certificates & Secrets**:  
   - Click "Certificates & Secrets" > "Certificates" > "Upload certificate".
   - Upload the `PnPAppCert.cer` created earlier.

5. **API Permissions**:  
   - Add the following permissions:
     - `SharePoint` > `Application permissions` > `Sites.FullControl.All`
     - `Directory.Read.All` (optional, for user lookups)
   - Click "Grant admin consent".

6. **Assign SharePoint App Permissions**:  
   - Follow [PnP docs](https://pnp.github.io/pnp-powershell/articles/authentication.html#certificate-authentication) if needed.

---

## 3. Running the Provisioning Script

Run **Create-EnterpriseAppCatalog.ps1** after configuring your Azure AD app:

```powershell
pwsh .\Create-EnterpriseAppCatalog.ps1
```

- The script will prompt for:
  - Tenant ID
  - Tenant short name
  - App/Client ID
  - Certificate path (the `.pfx`)
  - Certificate password
  - Site title, short name, and owner(s)
- Default values are provided for convenience—press Enter to use them or supply your own.
- The script will:
  - Connect to SharePoint Online using certificate authentication.
  - Create the site (if it doesn't exist).
  - Provision all lists, columns, and views.
  - Add sample data.

---

## 4. Connecting to SharePoint Online using PnP PowerShell

Once the site and lists are provisioned, connect using your Azure AD App and certificate:

```powershell
Connect-PnPOnline -Url https://<TenantName>.sharepoint.com/sites/<SiteShort> `
    -ClientId <Your-App-Client-Id> `
    -Tenant <Your-Tenant-Id> `
    -CertificatePath <Path-To-PFX> `
    -CertificatePassword (Read-Host -AsSecureString "Enter certificate password")
```

You now have full access to manage the Enterprise Application Catalog using PnP PowerShell.

---

## Troubleshooting

- **PowerShell 7 required:** The script will prompt to install it if not found.
- **PnP.PowerShell module issues:** The script installs or updates the module as needed.
- **Permission errors:** Ensure your Azure AD App has the correct permissions and admin consent is granted.
- **Certificate errors:** Make sure the `.pfx` password is correct and matches the certificate uploaded to Azure AD.

---

## Security Notes

- **Never commit certificates or passwords to source control.**
- **Change the default `$pfxPassword` in Create-Cert.ps1 to a strong, unique value.**
- Restrict access to the certificate files.

---

## Credits

Script by [andrew-kemp](https://github.com/andrew-kemp).  
Based on Microsoft PnP PowerShell and SharePoint provisioning best practices.

---
