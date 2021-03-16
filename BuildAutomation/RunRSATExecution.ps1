<#
SAMPLE CODE NOTICE

THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED, 
OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.  
THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.  
NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
#>

[Cmdletbinding()]
Param(
    [Parameter(Mandatory=$true, HelpMessage="One or more DevOps test suites to run. Specify suite names comma separated.")]
    [string[]]$TestSuitesToRun,

[string]$RSATInstallationPath,

    <#[Parameter(Mandatory=$false, HelpMessage="The installation folder of RSAT.")]
    [string]$RSATInstallationPath = $Env:DynamicsRSATFolder,#>

    [Parameter(Mandatory=$false, HelpMessage="Settings file to pass to the RSAT console application.")]
    [string]$SettingsFilePath = $(Join-Path -Path $Env:DynamicsRSATFolder -ChildPath "BuildSettings.settings"),

    [Parameter(Mandatory=$false, HelpMessage="Log folder location to use.")]
    [string]$LogFolder = $(Join-Path -Path $env:TEMP -ChildPath "RSATBuildAutomationLogs")
)

[int]$ExitCode = 0

Import-Module $(Join-Path -Path $PSScriptRoot -ChildPath "RSATBuildAutomationCommon.psm1") -Function "Get-TestSuiteResults","Write-Message" -Verbose

try
{
    # First locate or create the logs folder
    Write-Message "Validating log folder existence in the following location: $LogFolder"

    If(!(test-path $LogFolder))
    {
        Write-Message "Log folder was not found so creating the folder: $LogFolder"
        New-Item -ItemType Directory -Force -Path $LogFolder
    }

    # Don't start without any settings
    Write-Message "Validating settings to use."

    if(!(test-path $SettingsFilePath))
    {
        throw "No settings file found. Tried the following path: $SettingsFilePath"
    }

    Set-Location $RSATInstallationPath

    # Perform test execution for all the suites specified. Currently whenever a
    Write-Message "Initiating RSAT test execution..."

    foreach($CurrentSuite in $TestSuitesToRun)
    {
        $CurrentSuiteLogFile = $(Join-Path -Path $LogFolder -ChildPath "Suite-$CurrentSuite-ExecutionLog.log")

        Write-Message "Playback Test Suite $CurrentSuite"
        Write-Message "Starting RSAT ConsoleApp..." -Diag
        Write-Message "Working directory: ($(Get-Location))" -Diag
        
        Write-Message "------RSAT Console App output START-------" -Diag
        $RSATExecutable = Join-Path -Path $RSATInstallationPath -ChildPath "Microsoft.Dynamics.RegressionSuite.ConsoleApp.exe"
        .$RSATExecutable /settings $SettingsFilePath playbacksuite $CurrentSuite | Tee-Object -file $CurrentSuiteLogFile
        Write-Message "-------RSAT Console App output END--------" -Diag

        Write-Message "Parsing the results for test suite $CurrentSuite"
        [bool]$success = Get-TestSuiteResults -TestSuite $CurrentSuite -TestSuiteLogFile $CurrentSuiteLogFile

        # On test failure, continue test execution but mark exitcode to fail the pipeline step upon exit.
        if(!$success)
        {
            $ExitCode = -1
        }
        
        Write-Message "Test suite execution complete for test suite $CurrentSuite"
    }

    Write-Message "Removing the RSAT execution log folder $LogFolder"
    Remove-Item $LogFolder -Force -Recurse

    Write-Message "RSAT Test execution complete."
    
    # If at least one test failed, mark this as a pipeline step failure
    if($ExitCode -ne 0)
    {
        Write-Message "At least one of the test cases contained error. Please consult the Azure DevOps testplan to view the results. Failing the build for not passing all of the tests." -Error
    }
}
catch [System.Exception]
{
    Write-Message "$($_.Exception.ToString())" -Diag
    $ExitCode = -1
}

Exit $ExitCode