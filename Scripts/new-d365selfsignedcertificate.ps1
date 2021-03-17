[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 1)]
    [string] $CertificateFileName = (Join-Path $env:TEMP "authcert.cer"),

    [Parameter(Mandatory = $false, Position = 2)]
    [string] $PrivateKeyFileName = (Join-Path $env:TEMP "authcert.pfx")
)

[int]$ExitCode = 0
try {
    $Password = new-object System.Security.SecureString

	$currentDate = Get-Date -Format "yyyy-MM-dd HH:mm"

    # First generate a self-signed certificate and place it in the local store on the machine
    $certificate = New-SelfSignedCertificate -dnsname 127.0.0.1 -CertStoreLocation cert:\LocalMachine\My -Provider "Microsoft Strong Cryptographic Provider" -FriendlyName "RSAT certificate created on $currentDate"
    $certificatePath = 'cert:\localMachine\my\' + $certificate.Thumbprint

    # Export certificate
    $cerFile = Export-Certificate -Cert $certificate -FilePath $CertificateFileName

    # Export the private key
    $pfxFile = Export-PfxCertificate -cert $certificatePath -FilePath $PrivateKeyFileName -Password $Password

    # Import the certificate into the local machine's trusted root certificates store
    $cert = Import-Certificate -FilePath $CertificateFileName -CertStoreLocation Cert:\LocalMachine\Root

    Write-Host -NoNewline $certificate.Thumbprint
}
catch [System.Exception]
{
    # Write-Error -Message "Something went wrong while generating the self-signed certificate and installing it into the local machine's trusted root certificates store." -Exception $_.Exception
    Write-Error -Exception $_.Exception
    $ExitCode = -1
}

Exit $ExitCode
