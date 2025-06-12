# Set variables
$certFolder = "C:\certs"
$certSubject = "CN=PnPAppCert"
$pfxPath = Join-Path $certFolder "PnPAppCert.pfx"
$cerPath = Join-Path $certFolder "PnPAppCert.cer"
$pfxPassword = "123456" # Change this to a strong password

# Create cert folder if it doesn't exist
if (!(Test-Path -Path $certFolder)) {
    New-Item -ItemType Directory -Path $certFolder | Out-Null
    Write-Host "Created certificate folder at $certFolder"
}

# Create self-signed certificate
$cert = New-SelfSignedCertificate `
    -Subject $certSubject `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -NotAfter (Get-Date).AddYears(2)

# Export public key (.cer)
Export-Certificate -Cert $cert -FilePath $cerPath

# Export private key (.pfx)
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password (ConvertTo-SecureString -String $pfxPassword -Force -AsPlainText)

Write-Host "Certificate files exported to $certFolder"
