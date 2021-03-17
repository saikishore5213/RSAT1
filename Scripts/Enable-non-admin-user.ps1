<#

.SYNOPSIS
    - Part 2. Script to enable/disable a non-admin user of RSAT.

.DESCRIPTION
    - This script has two modes:
        1. Enable non-admin user.
        2. Disable non-admin user.

    - Required parameters:
        - [action] – Run enable or disable mode. Two possible values: "enable" or "disable".
        - [user] – The local username. Us the format "domain\userName"
        - [thumbprint] – Certificate thumbprint. Must be the same as specified on the RSAT settings form.

.EXAMPLE
    1. Enable non-admin user:
    
        .\Enable-non-admin-user.ps1 "enable" "TESTDOMAIN\testuser" "23055S5D1974C5E9467690DE4328FA6AC533632D"

    2. Disable non-admin user:

        .\Enable-non-admin-user.ps1 "disable" "TESTDOMAIN\testuser" "23055S5D1974C5E9467690DE4328FA6AC533632D"

.LINK
    - Links to further documentation.

.NOTES
    - Detail on what the script does:
        1. Configure port access to the specified user and reserve the port.
        2. Provide access to the private key to the specified user.
        3. Provide access with FullControl to current installtion folder of the RSAT tool to the specified user.

    - If you run scripts with "disable" mode, all access will be removed for the specified user.

#>

param(
    [Parameter(Mandatory=$true)][string] $action,
    [Parameter(Mandatory=$true)][string] $user,
    [Parameter(Mandatory=$true)][string] $thumbprint
    )


$appId = "292EA88F-C7B6-47CC-9CDD-6392C31BF0D0"
$port = "0.0.0.0:745"
$url = "https://+:745/"

$permission = "FullControl"

function GivePortAccessToUser($user)
{
    if([string]::IsNullOrEmpty($user))
    {
        Write-Host "User is null or empty. Access will not be given to user to port."
    }
    else 
    {
        $urlPermissions = (Invoke-Expression -Command "netsh http show urlacl url=$url") | Where-Object { ($_) -and ($_.Contains("Reserved URL")) }
        
        if ($urlPermissions.Length -ne 0)
        {
            Write-Host "URL $url already reserved, removing reservation..." -ForegroundColor Yellow
            RemoveReservation($url)
        }

        Write-Host "Giving access to user to a single port $url so JsDispatcher tests can create self-hosted service"

        $output = Invoke-Expression -Command "netsh http add urlacl url=$url user=`"$user`" listen=yes"

        if ($LASTEXITCODE -ne 0)
        {
            throw "WARNING: PerfSDK - $url permissions failed with code $LASTEXITCODE. Output: $output"
        }
        
        Write-Host "URL $url permitted and reserved for user `"$user`""
    }
}

function RemoveReservation($url)
{
    Write-Host "Removing URL $url reservation..."

    $urlPermissions = (Invoke-Expression -Command "netsh http show urlacl url=$url") | Where-Object { ($_) -and ($_.Contains("Reserved URL")) }

    if ($urlPermissions.Length -ne 0)
    {
        $output = Invoke-Expression -Command "netsh http delete urlacl url=$url"

        if ($LASTEXITCODE -ne 0)
        {
            throw "URL $url reservation removal failed with code $LASTEXITCODE. Output: $output"
        }

        Write-Host "URL $url reservation successfully removed"
    }
    else 
    {
        Write-Host "URL $url reservation already removed" -ForegroundColor Yellow
    }
}

function EditPermissionsToCertificateForUser($userName, $thumbprintValue, $actionName)
{
    if([string]::IsNullOrEmpty($thumbprintValue))
    { 
        throw "Thumbprint for local host SSL certificate is null or empty."
    }

    if([string]::IsNullOrEmpty($userName))
    { 
        throw "User name is null or empty."
    }

    $resultFromCertStore = Get-ChildItem -Path Cert:\\ -Recurse | Where-Object { $_.Thumbprint -like $thumbprintValue }

    if ([string]::IsNullOrEmpty($resultFromCertStore))
    {
        throw "Not a valid thumprint $thumbprintValue."
    }
    else
    {
        try
        {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule $userName, $permission, allow
            $root = "c:\programdata\microsoft\crypto\rsa\machinekeys"
           
            $keyname = $resultFromCertStore.privatekey.cspkeycontainerinfo.uniquekeycontainername
            $p = [io.path]::combine($root, $keyname)

            if ([io.file]::exists($p))
            {
                $acl = get-acl -path $p

                if($actionName -eq "add")
                {
                    $acl.AddAccessRule($rule)
                }

                if($actionName -eq "delete")
                {
                    $acl.RemoveAccessRule($rule)
                }

                echo $p
                set-acl $p $acl
            }
            
        }
        catch 
        {
            throw $_
        }
    }
    
}


function EditPermissionsToInstallationFolderForUser($userName, $actionName)
{
    if([string]::IsNullOrEmpty($userName))
    { 
        throw "User name is null or empty."
    }
    
    try
    {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($userName, $permission, "ContainerInherit,ObjectInherit", "None", "Allow")

        $installationpath = (get-item $PSScriptRoot ).parent.FullName

        $acl = get-acl -path $installationpath

        if($actionName -eq "add")
        {
            $acl.AddAccessRule($rule)
        }

        if($actionName -eq "delete")
        {
            $acl.RemoveAccessRule($rule)
        }

        echo $installationpath
        set-acl $installationpath $acl
            
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
            GivePortAccessToUser $user

            EditPermissionsToCertificateForUser $user $thumbprint "add"

            EditPermissionsToInstallationFolderForUser $user "add"

            Write-Host "Non-admin user was successfully enabled" -ForegroundColor Green
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
            RemoveReservation $url

            EditPermissionsToCertificateForUser $user $thumbprint "delete"

            EditPermissionsToInstallationFolderForUser $user "delete"
            
            Write-Host "Non-admin user was successfully disabled" -ForegroundColor Green    
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            Write-Host $ErrorMessage -ForegroundColor Red
        }
    }

    default { Write-Host "Not a correct action name." }
}