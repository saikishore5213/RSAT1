Param(
    [string]$SubscriptionId,
    [string]$KeyVaultCertPath,
    [string]$KeyVaultName,
    [string]$ResourceGroupName,
    [string]$KeyVaultAppDisplayName,
    [string]$ApplicationId,
    [switch]$CreateNewApplication)

function CheckInputArguments($SubscriptionId,$KeyVaultCertPath,$KeyVaultName,$ResourceGroupName,$CreateNewApplication,$KeyVaultAppDisplayName,$ApplicationId)
{
    Write-Host "Validating input arguments"
    try
    {
        # Check all arguments were passed in
        if(!($SubscriptionId)) {
            throw "SubscriptionId must be specified."
        }
        if(!($KeyVaultCertPath)) {
            throw "KeyVaultCertPath must be specified."
        }
        if(!($KeyVaultName)) {
            throw "KeyVaultName must be specified."
        }
        if(!($ResourceGroupName)) {
            throw "ResourceGroupName must be specified."
        }
        if($CreateNewApplication -and -not($KeyVaultAppDisplayName)) {
            throw "KeyVaultAppDisplayName must be specified when CreateNewApplication is set to true."
        }
        if(-not($CreateNewApplication) -and -not($ApplicationId)) {
            throw "ApplicationId must be specified if CreateNewApplication is false. If you want a new application to be created, specify a KeyVaultAppDisplayName and run the script with -CreateNewApplication specified."
        }

        # Check that the subscription, resource group and Key Vault all exist
        $subscription = Get-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
        ConnectToAzureSubscription $SubscriptionId            
        
        $resrouceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        if(!(Get-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName))
        {
            throw "A Key Vault named $KeyVaultName does not exist in resource group $ResourceGroupName"
        }

        # Check that the application exists if not creating a new application
        # Otherwise, check that the display name is unique so that a new application can be created successfully
        if(!$CreateNewApplication -and !(Get-AzureRmADApplication -ApplicationId $ApplicationId))
        {
            throw "An application with ApplicationId $ApplicationId does not exist in current tenant."
        }
        elseif ($CreateNewApplication -and (Get-AzureRmADApplication -DisplayName $KeyVaultAppDisplayName))
        {
            throw "An application already exists with $KeyVaultAppDisplayName.  Rerun the setup script with a unique display name."
        }

        # Check that the Key Vault certificate was passed in correctly
        if (!(Test-Path -Path $KeyVaultCertPath))
        {
            throw "Key Vault certificate does not exist at $KeyVaultCertPath"
        }
        elseif([IO.Path]::GetExtension($KeyVaultCertPath) -ne ".pfx")
        {
            throw "KeyVaultCertPath does not specify a *.pfx file"
        }
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Error "Encountered an error: $ErrorMessage"
        throw "Failed to validate one of the input arguments. Resolve the issues listed before rerunning the setup script."
    }
}

function InstallAndImportAndLoginToAzureRm()
{
    if (!(Get-Module -ListAvailable -Name AzureRM))
    {
        Write-Host "Installing AzureRm module for CurrentUser. Please say 'Yes to All' when prompted."
        Install-Module AzureRM -Scope CurrentUser
    }

    Write-Host "Importing AzureRM module"
    Import-Module AzureRM
    
    Write-Host "Logging into Azure AD account"
    LoginToAzure
}

function LoginToAzure()
{
    $AzureContext = Get-AzureRmContext
    if(-not($AzureContext)) 
    {
        $account= Connect-AzureRmAccount -ErrorAction Stop
    }
}

function ConnectToAzureSubscription($SubscriptionId)
{
    $subscription = select-AzureRmSubscription -SubscriptionId $SubscriptionId
}

function ImportKeyVaultCertificate($KeyVaultCertPath)
{
    Write-Host "Importing Key Vault certificate"    

    $x509 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $x509.Import($KeyVaultCertPath)
    $script:CertThumbprint = $x509.Thumbprint

    $CertValue = [System.Convert]::ToBase64String($x509.GetRawCertData())
    return $CertValue
}

function ConfigureAzureAdApplicationWithCert($CreateNewApplication, $KeyVaultAppDisplayName, $ApplicationId, $CertValue)
{
    if ($CreateNewApplication)
    {
        CreateApplication -KeyVaultAppDisplayName $KeyVaultAppDisplayName -CertValue $CertValue
    }
    else
    {
        AddCertificateAsAppCredentialToExistingApplication -ApplicationId $ApplicationId -CertValue $CertValue
    }
}

function CreateApplication($KeyVaultAppDisplayName, $CertValue)
{
    $AppUrl = "http://" + $KeyVaultAppDisplayName
    Write-Host "Creating new application with display name of $KeyVaultAppDisplayName and application URL of $AppUrl"        

    $AzureActiveDirectoryApp = New-AzureRmADApplication -DisplayName $KeyVaultAppDisplayName -HomePage $AppUrl -IdentifierUris $AppUrl -CertValue $CertValue    
    $ServicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $AzureActiveDirectoryApp.ApplicationId -ErrorAction Stop

    $script:ApplicationId = $AzureActiveDirectoryApp.ApplicationId
    Write-Host "New application ID is $script:ApplicationId"        
}

function AddCertificateAsAppCredentialToExistingApplication($ApplicationId, $CertValue)
{
    Write-Host "Adding the Key Vault certificate as a new credential to the application with ID $ApplicationId"        
    New-AzureRmADAppCredential -ApplicationId $ApplicationId -CertValue $CertValue -ErrorAction Stop
}

function AddApplicationAsKeyVaultAccessPolicy($KeyVaultName, $ResourceGroupName, $ApplicationId)
{
    Write-Host "Adding application with ID $ApplicationId as a Key Vault access policy"        
    Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVaultName -ServicePrincipalName $ApplicationId -PermissionsToSecrets get -ResourceGroupName $ResourceGroupName -ErrorAction Stop
}

function PrintKeyVaultCloudEnvironmentConfigValues($KeyVaultName, $ApplicationId)
{
    Write-Host ""    
    Write-Host "Specify the following key value pairs in your CloudEnvironment.config file:"
    Write-Host "---------------------------------------------------------------------------"

    $keyvault = Get-AzureRmKeyVault -VaultName $KeyVaultName
    $keyvaultUri = $keyvault.VaultUri

    Write-Host "                  KeyVaultUrl : $keyvaultUri"
    Write-Host "KeyVaultCertificateThumbprint : $script:CertThumbprint"
    Write-Host "             KeyVaultClientId : $ApplicationId"
    Write-Host "" 
}

InstallAndImportAndLoginToAzureRm
CheckInputArguments -SubscriptionId $SubscriptionId -KeyVaultCertPath $KeyVaultCertPath -KeyVaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -CreateNewApplication $CreateNewApplication -KeyVaultAppDisplayName $KeyVaultAppDisplayName -ApplicationId $ApplicationId
$CertValue = ImportKeyVaultCertificate -KeyVaultCertPath $KeyVaultCertPath
ConfigureAzureAdApplicationWithCert -CreateNewApplication $CreateNewApplication -KeyVaultAppDisplayName $KeyVaultAppDisplayName -ApplicationId $ApplicationId -CertValue $CertValue
AddApplicationAsKeyVaultAccessPolicy -KeyVaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -ApplicationId $ApplicationId

PrintKeyVaultCloudEnvironmentConfigValues -KeyVaultName $KeyVaultName -ApplicationId $ApplicationId
# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCHcfc8kh1kIHyA
# 8/DFN7ljkNUpWBG22OYdLIKR3ziQFKCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
# chVZQMcJAAAAAAGHMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAwMzA0MTgzOTQ3WhcNMjEwMzAzMTgzOTQ3WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOt8kLc7P3T7MKIhouYHewMFmnq8Ayu7FOhZCQabVwBp2VS4WyB2Qe4TQBT8aB
# znANDEPjHKNdPT8Xz5cNali6XHefS8i/WXtF0vSsP8NEv6mBHuA2p1fw2wB/F0dH
# sJ3GfZ5c0sPJjklsiYqPw59xJ54kM91IOgiO2OUzjNAljPibjCWfH7UzQ1TPHc4d
# weils8GEIrbBRb7IWwiObL12jWT4Yh71NQgvJ9Fn6+UhD9x2uk3dLj84vwt1NuFQ
# itKJxIV0fVsRNR3abQVOLqpDugbr0SzNL6o8xzOHL5OXiGGwg6ekiXA1/2XXY7yV
# Fc39tledDtZjSjNbex1zzwSXAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUhov4ZyO96axkJdMjpzu2zVXOJcsw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDU4Mzg1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAixmy
# S6E6vprWD9KFNIB9G5zyMuIjZAOuUJ1EK/Vlg6Fb3ZHXjjUwATKIcXbFuFC6Wr4K
# NrU4DY/sBVqmab5AC/je3bpUpjtxpEyqUqtPc30wEg/rO9vmKmqKoLPT37svc2NV
# BmGNl+85qO4fV/w7Cx7J0Bbqk19KcRNdjt6eKoTnTPHBHlVHQIHZpMxacbFOAkJr
# qAVkYZdz7ikNXTxV+GRb36tC4ByMNxE2DF7vFdvaiZP0CVZ5ByJ2gAhXMdK9+usx
# zVk913qKde1OAuWdv+rndqkAIm8fUlRnr4saSCg7cIbUwCCf116wUJ7EuJDg0vHe
# yhnCeHnBbyH3RZkHEi2ofmfgnFISJZDdMAeVZGVOh20Jp50XBzqokpPzeZ6zc1/g
# yILNyiVgE+RPkjnUQshd1f1PMgn3tns2Cz7bJiVUaqEO3n9qRFgy5JuLae6UweGf
# AeOo3dgLZxikKzYs3hDMaEtJq8IP71cX7QXe6lnMmXU/Hdfz2p897Zd+kU+vZvKI
# 3cwLfuVQgK2RZ2z+Kc3K3dRPz2rXycK5XCuRZmvGab/WbrZiC7wJQapgBodltMI5
# GMdFrBg9IeF7/rP4EqVQXeKtevTlZXjpuNhhjuR+2DMt/dWufjXpiW91bo3aH6Ea
# jOALXmoxgltCp1K7hrS6gmsvj94cLRf50QQ4U8Qwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVZzCCFWMCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAYdyF3IVWUDHCQAAAAABhzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgm3Y81rD8
# BPhEi1uBHJ7uw65zff3iXVyUix0m55+0BzswQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQAUPVWJiT8hJ3CHfXYf0cCV7QLhzkZRiQkPZALlNlTh
# AooH6uHcp1TH9I1fowip3qe076qbtm9hK1Ic/ft5gzld7j25or09B8mOPXvuPbBv
# dw6g3iM/wra4vB0PLsXmV1QspJ1QkukcZ9wIskZjWgYQ1i8wmld1iJlK65HACOU+
# l5GihqeCbEhp1eJ/UEvCbM3tQrpBk7wndRyT7MUPa6vv7W2GVFy648a9B/6Xk3fL
# 1g9fFUuiiBhse+85eV+12HcaTQZtqCRBOdkbeFL5IMvFI+hYwGmPA9Y3+CUqmUnU
# qK/OVZMWesWMwahUC2DQDXc7v+Zwzor0ZwLXuqeDH0EyoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIByo0e3/xxXZQBojaaExWhZ7onPKhQqWAhmw+zXb
# uynzAgZfiHWS0m4YEzIwMjAxMTE3MDcyMjM5LjA5NVowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjpGODdBLUUzNzQtRDdCOTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABL7GnF3lWlBeHAAAA
# AAEvMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTE5MTIxOTAxMTUwNloXDTIxMDMxNzAxMTUwNlowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGODdB
# LUUzNzQtRDdCOTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKh8VkvVIwXD8sn0zT2n
# EdyEZ9UNHY7ACbOZA4obAHvD1hauw9K1Z2lRWG+m8Ars9l35GoMXdPgshM3hZKQW
# fhrLnF9/GDZoilhc2LhMqNPXs06rAJ8YODB6i0Cg1CFCYnyOYvywXKY3xGJN09Dg
# PXWfczEm2P/a3rmrXMrK5EFc3ahxrC51c+UuAMKV9xJyzJVLShPwPBJl+CjdMDPJ
# f24DZXIYec3gCN2xean1DFCI0gaqJprMeL4Om1KY2AZMIgBPEkoY1N7AI5e7ybkI
# L8+Mz3inijb4rDTkXk86ztUwy4bdc1MyKe2j2odT+QIDA2+M8cMTIGlKn7EyD2NN
# XU8CAwEAAaOCARswggEXMB0GA1UdDgQWBBSml/VRpBNFkAMDiqcoqWi85j/qljAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQB4q6ilv2SlGvJD/7dbfoIKZBO2i6YA
# wckw57TpCrt2+SAx2dcF7JvRMCPhLCSgqjyNcJRs40cEXPbLdzZMJHzcv73AF7L6
# mWZXg2aBjG1Sc5qM4jjE/nwIX+C6/odm5/asU4JIlFCuUZjzqdir18HkRVQve2Hw
# V0lCXHQs+V3m9DyyA9b6LSIk3GOFZu7F11Wyx/5dVXisPPTPwh9JXfMD9W173M1+
# ZZycmO03lUc4G1FilgpxWNdgWn/DO9ZhoW5yN6+BUddnJ4cCcCjcg8sB5rktPP8p
# VZAQ7aUqkAeqo+FuCkAUAdJRESCpR5wgSPtVvFPMjONE36DbKtfzkfiHMIIGcTCC
# BFmgAwIBAgIKYQmBKgAAAAAAAjANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJv
# b3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMTAwNzAxMjEzNjU1WhcN
# MjUwNzAxMjE0NjU1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKkdDbx3EYo6IOz8E5f1+n9plGt0
# VBDVpQoAgoX77XxoSyxfxcPlYcJ2tz5mK1vwFVMnBDEfQRsalR3OCROOfGEwWbEw
# RA/xYIiEVEMM1024OAizQt2TrNZzMFcmgqNFDdDq9UeBzb8kYDJYYEbyWEeGMoQe
# dGFnkV+BVLHPk0ySwcSmXdFhE24oxhr5hoC732H8RsEnHSRnEnIaIYqvS2SJUGKx
# Xf13Hz3wV3WsvYpCTUBR0Q+cBj5nf/VmwAOWRH7v0Ev9buWayrGo8noqCjHw2k4G
# kbaICDXoeByw6ZnNPOcvRLqn9NxkvaQBwSAJk3jN/LzAyURdXhacAQVPIk0CAwEA
# AaOCAeYwggHiMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTVYzpcijGQ80N7
# fEYbxTNoWoVtVTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDCBoAYDVR0g
# AQH/BIGVMIGSMIGPBgkrBgEEAYI3LgMwgYEwPQYIKwYBBQUHAgEWMWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9QS0kvZG9jcy9DUFMvZGVmYXVsdC5odG0wQAYIKwYB
# BQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AUABvAGwAaQBjAHkAXwBTAHQAYQB0AGUA
# bQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAAfmiFEN4sbgmD+BcQM9naOh
# IW+z66bM9TG+zwXiqf76V20ZMLPCxWbJat/15/B4vceoniXj+bzta1RXCCtRgkQS
# +7lTjMz0YBKKdsxAQEGb3FwX/1z5Xhc1mCRWS3TvQhDIr79/xn/yN31aPxzymXlK
# kVIArzgPF/UveYFl2am1a+THzvbKegBvSzBEJCI8z+0DpZaPWSm8tv0E4XCfMkon
# /VWvL/625Y4zu2JfmttXQOnxzplmkIz/amJ/3cVKC5Em4jnsGUpxY517IW3DnKOi
# PPp/fZZqkHimbdLhnPkd/DjYlPTGpQqWhqS9nhquBEKDuLWAmyI4ILUl5WTs9/S/
# fmNZJQ96LjlXdqJxqgaKD4kWumGnEcua2A5HmoDF0M2n0O99g/DhO3EJ3110mCII
# YdqwUB5vvfHhAN/nMQekkzr3ZUd46PioSKv33nJ+YWtvd6mBy6cJrDm77MbL2IK0
# cs0d9LiFAR6A+xuJKlQ5slvayA1VmXqHczsI5pgt6o3gMy4SKfXAL1QnIffIrE7a
# KLixqduWsqdCosnPGUFN4Ib5KpqjEWYw07t0MkvfY3v1mYovG8chr1m1rtxEPJdQ
# cdeh0sVV42neV8HR3jDA/czmTfsNv11P6Z0eGTgvvM9YBS7vDaBQNdrvCScc1bN+
# NR4Iuto229Nfj950iEkSoYIC0jCCAjsCAQEwgfyhgdSkgdEwgc4xCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBP
# cGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpG
# ODdBLUUzNzQtRDdCOTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAM/CZCUpclQ9qfr/r3y9osIIPSmSggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AONdy6gwIhgPMjAyMDExMTcwODEwMTZaGA8yMDIwMTExODA4MTAxNlowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA413LqAIBADAKAgEAAgIoYQIB/zAHAgEAAgIRHjAK
# AgUA418dKAIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAKG+kc6f6Cf/cwwL
# yey2M/lqJkwZ8aRGrJhBW/umH+yoYwBk0/QkFQVQCLh1AL3OCBfOyc4+QakFLgjT
# ruPnm/AvG9GMjdymxOSwmjm3zxBXZ2clY9Cw70dxOR+opH3h3i4s6nr3dBl5rXDy
# t+8iWb2IKsDab26OlFR4aTrSlxh0MYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAEvsacXeVaUF4cAAAAAAS8wDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgW4hErQEubgPmDGygN4eRDcioMmZVei93AVi8UPm3eA0wgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBC5RecGZvugnvVXg80zlrGv1uV35LNk+H9dBj3
# ChFPvTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# L7GnF3lWlBeHAAAAAAEvMCIEIGUcT2xqwAut50Uua6WePsL2X5zMbYIyUpVz74kh
# n1K9MA0GCSqGSIb3DQEBCwUABIIBAH4k9okoZ9aH4K+npTOFfO86w9E6ZknX87ic
# NytGrtdnzxknvSEkqs8hvngTSqBADq3QY7+d8ppPygGeaYYB6xFv/ya7aEMlDw6k
# BpOKdIesOiUM+EB8eoCf7osM5ecZaX7xmk+qjIcjImhVJy6Uadwf8de2zL4r/uCd
# stUaeJaHhn0dlIWXBlOgSknCvojyw8lziGpyHQ0nmidi7jU8EV/mUlfpuaEt/I0d
# q+cOVghxRqME0LUz2MvplZZ8IcJcwHLTod1WhddxiAU4fjV1RVA8gG29y/+DKKXg
# kLMd+4GnMUNeIy1SuoyLd9p1QtJ7IB4Ch6Wlfp29FeDKN9YuUUE=
# SIG # End signature block
