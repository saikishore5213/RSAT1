<#
SAMPLE CODE NOTICE

THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED, 
OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.  
THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.  
NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
#>

$totalMarker = 'Tests:'
$passedMarker = 'Passed:'
$failedMarker = 'Failed:'

<#
.SYNOPSIS
    Get test results for a specific test suite.
.RETURNS
#>
function Get-TestSuiteResults ([string]$TestSuite, [string]$TestSuiteLogFile)
{
    [bool]$success = $true

    # Locate the log file to parse
    if(!(Test-Path $TestSuiteLogFile))
    {
        Write-Message "Unable to parse the test results for test suite $TestSuite as the log file could not be located. Tried log file $TestSuiteLogFile" -Error
    }

    # RSAT failure can be identified on the last line of the log file
    $lastine = Get-content -tail 1 -Path $TestSuiteLogFile

    if ($lastine.Contains("Error"))
    {
        # Do not throw exceptions as we want all the test suites to run during build to get an overall test result accross all suites
        Write-Message "RSAT execution has failed." -Error
        $success = $false
    }

    if($success)
    {
        $totalTests = Get-Value -source $lastine -start $totalMarker -end $passedMarker
        $passedTests = Get-Value -source $lastine -start $passedMarker -end $failedMarker
        $failedTests = Get-Value -source $lastine -start $failedMarker

        Write-Message "Total tests: $totalTests"
        Write-Message "Passed tests: $passedTests"
        Write-Message "Failed tests: $failedTests"

        if ($failedTests  -gt 0)
        {
            # Do not throw exceptions as we want all the test suites to run during build to get an overall test result accross all suites
            Write-Message "RSAT Execution finished with failed tests." -Error
            $success = $false
        }
    }

    return $success
}

function Get-Value
{
    Param ([string]$source, [string]$start, [string]$end)
    if (!$end)
    {
        $scanlength = $source.Length - ($source.IndexOf($start) + $start.Length)
    }
    else
    {
        $scanlength = $source.IndexOf($end) - $source.IndexOf($start) - $start.Length
    }
    $res = $source.Substring($source.IndexOf($start) + $start.Length, $scanlength)
    $res = $res -as [int]
    return $res
}

function Write-Message
{
    [Cmdletbinding()]
    Param([string]$Message, [switch]$Error, [switch]$Warning, [switch]$Diag)

    # Get verbose preference from caller to make sure the variable is inherited
    $VerbosePreference = $PSCmdlet.GetVariableValue("VerbosePreference")

    # For writing to host use a local time stamp.
    [string]$FormattedMessage = "$([DateTime]::Now.ToLongTimeString()): $($Message)"
    
    # If message is of type Error, use Write-Error.
    if ($Error)
    {
        Write-Error $FormattedMessage
    }
    else
    {
        # If message is of type Warning, use Write-Warning.
        if ($Warning)
        {
            Write-Warning $FormattedMessage
        }
        else
        {
            # If message is of type Verbose, use Write-Verbose.
            if ($Diag)
            {
                Write-Verbose $FormattedMessage
            }
            else
            {
                Write-Host $FormattedMessage
            }
        }
    }
}