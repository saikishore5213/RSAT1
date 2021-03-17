<#

.SYNOPSIS
    - Part 1. Script to enable/disable non-admin mode for the RSAT tool.

.DESCRIPTION
    - This script has two modes:
        1. Enable non-admin mode.
        2. Disable non-admin mode.

    - This will run steps that are not user specific

    - Required parameters:
        - [action] – Run enable or disable mode. Two possible values: "enable" or "disable".
        - [thumbprint] – Certificate thumbprint. Must be the same as specified on the RSAT settings form.

.EXAMPLE
    1. Enable non-admin mode:
    
        .\Enable-non-admin-mode.ps1 "enable" "23055S5D1974C5E9467690DE4328FA6AC533632D"

    2. Disable non-admin mode:

        .\Enable-non-admin-mode.ps1 "disable" "23055S5D1974C5E9467690DE4328FA6AC533632D"

.LINK
    - Links to further documentation.

.NOTES
    - Detail on what the script does:
        1. Configure binding between SSL certificate and http port.
        2. Update RSAT tool's configuration file to enable/disable non admin mode.

    - If you run scripts with "disable" mode, all bindings and configuration file changes will be removed.
#>

param(
    [Parameter(Mandatory=$true)][string] $action,
    [Parameter(Mandatory=$false)][string] $thumbprint
    )


$appId = "292EA88F-C7B6-47CC-9CDD-6392C31BF0D0"
$port = "0.0.0.0:745"
$url = "https://+:745/"

$cloudEnvironmentConfig = "CloudEnvironment.config"
$cloudEnvironmentDefaultConfig = "CloudEnvironment.default.config"


function BindCertToPort($thumbprint)
{
    if([string]::IsNullOrEmpty($thumbprint))
    { 
        throw "Thumbprint for local host SSL certificate is null or Empty. The cert will not be bound to the port for JsDispatcher tests."
    }
    else 
    {
        $resultFromCertStore = Get-ChildItem -Path Cert:\\ -Recurse | Where-Object { $_.Thumbprint -like $thumbprint }

        if ([string]::IsNullOrEmpty($resultFromCertStore))
        {
            throw "Not a valid thumprint $thumbprint."
        }
        else
        {
            $sslBindings = (Invoke-Expression -Command "netsh http show sslcert ipport=$port") | Where-Object { ($_) -and ($_.Contains("IP:port")) }

            if ($sslBindings.Length -ne 0)
            {
                Write-Host "Port $port already bound, removing binding..."  -ForegroundColor Yellow
                RemoveBinding($port)
            }

            Write-Host "Binding cert with thumbprint value $thumbprint to port $port..."
            
            $command = "netsh http add sslcert ipport=$port certhash='$thumbprint' appid='{$appId}'"
            
            $output = Invoke-Expression -Command $command

            if ($LASTEXITCODE -ne 0)
            {
                throw "PerfSDK - Binding cert to port failed with code $LASTEXITCODE. Output: $output"
            }

            Write-Host "SSL certificate successfully bound to port $port."
        }
    }
}

function RemoveBinding($port) {

    $sslBindings = (Invoke-Expression -Command "netsh http show sslcert ipport=$port") | Where-Object { ($_) -and ($_.Contains("IP:port")) }

    if ($sslBindings.Length -ne 0)
    {
        $output = Invoke-Expression -Command "netsh http delete sslcert ipport=$port"

        if ($LASTEXITCODE -ne 0)
        {
            throw "Port $port binding removal failed with code $LASTEXITCODE. Output: $output"
        }

        Write-Host "Port $port binding successfully removed"
    }
    else 
    {
        Write-Host "Port $port binding already removed"  -ForegroundColor Yellow
    }
}


function EditCloudEnvironmentConfig($action)
{
    $installationpath = (get-item $PSScriptRoot ).parent.FullName
    
    $configFilePath = Join-Path -Path $installationpath -ChildPath $cloudEnvironmentConfig
    $configDefaultFilePath = Join-Path -Path $installationpath -ChildPath $cloudEnvironmentDefaultConfig

    if($action -eq "add") {

        if (Test-Path $configFilePath -PathType leaf)
        {
            AddParameterToConfig $configFilePath
        }

        if (Test-Path $configDefaultFilePath -PathType leaf)
        {
            AddParameterToConfig $configDefaultFilePath
        }
    }
    
    if($action -eq "delete") {

        if (Test-Path $configFilePath -PathType leaf)
        {
            RemoveParameterFromConfig $configFilePath
        }

        if (Test-Path $configDefaultFilePath -PathType leaf)
        {
            RemoveParameterFromConfig $configDefaultFilePath
        }
    }
}


function AddParameterToConfig($path) {
    
    try 
    {
        Write-Host "Updating config file $path to enable non-admin mode..."

        $xml = [xml](get-content $path)
        $xml.Load($path)

        $targetElem = (($xml.EnvironmentalConfigSettings.EnvironmentalConfigSettingsCollection.EnvironmentalConfigSetting.ExecutionConfigurationsNodes|where {$_.ConfigurationName -eq "PRF"}))

        $nonAdminElem = ($targetElem.ChildNodes|where{ $_.Key -eq "IsPerfSdkTest"})

        if($nonAdminElem -eq $null)
        {

            $addElem = $xml.CreateElement("ConfigurationSpecificDetails")
            $addKeyAtt = $xml.CreateAttribute("Key")
            $addKeyAtt.Value = "IsPerfSdkTest"
            $addValueAtt = $xml.CreateAttribute("Value")
            $addValueAtt.Value = "True"
            $addElem.Attributes.Append($addKeyAtt)
            $addElem.Attributes.Append($addValueAtt)
            $targetElem.AppendChild($addElem)
        }
        else 
        {
            $nonAdminElem.Value = "True";
        }

        $xml.Save($path)

        Write-Host "Configuration file $path was successfully updated to enable non-admin mode."
    }
    catch 
    {
        throw $_  
    }
}

function RemoveParameterFromConfig($path) {
    try 
    {
        Write-Host "Updating config file $path to disable non-admin mode..."

        $xml = [xml](get-content $path)
        $xml.Load($path)

        $targetElem = (($xml.EnvironmentalConfigSettings.EnvironmentalConfigSettingsCollection.EnvironmentalConfigSetting.ExecutionConfigurationsNodes|where {$_.ConfigurationName -eq "PRF"}))

        $removeElem = ($targetElem.ChildNodes|where{ $_.Key -eq "IsPerfSdkTest"})

        if($removeElem -ne $null) {

            $targetElem.RemoveChild($removeElem)
        }

        $xml.Save($path)

        Write-Host "Configuration file $path was successfully updated to disable non-admin mode."
    }
    catch
    {
        throw $_
    }
}


switch ($action) {

    'enable' {
        try 
        {
            
            BindCertToPort $thumbprint
            
            EditCloudEnvironmentConfig "add"

            Write-Host "Non-admin mode was successfully enabled" -ForegroundColor Green
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            Write-Host $ErrorMessage -ForegroundColor Red
        }
    }

    'disable' {
        try 
        {
            RemoveBinding $port
            
            EditCloudEnvironmentConfig "delete"

            Write-Host "Non-admin mode was successfully disabled" -ForegroundColor Green
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            Write-Host $ErrorMessage -ForegroundColor Red
        }
    }

    default { Write-Host "Not a correct action name." }
}