# Fallback message strings in en-US
DATA localizedData
{
ConvertFrom-StringData @'    
    NoHyperVModule=Hyper-V PowerShell Module not found.
    CheckGIS=Checking if Guest integration Services on VM {0} are running.
    GISRunning=Guest Integration Services on VM {0} are running.
    GISNotRunning=Guest Integration Services on VM {0} are not running.
    Retry=Check for guest integration services in another {0} seconds.
    CheckError=Guest Integration Services on VM {0} failed to be in running state after {1} seconds.
'@
}

if (Test-Path "$PSScriptRoot\$PSCulture")
{
    Import-LocalizedData LocalizedData -filename "cWaitForVMGuestIntegration.psd1" -BaseDirectory "$PSScriptRoot\$PSCulture"
}

function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory)]
        [String] $VMName,
        [UInt64] $RetryIntervalSec = 10,
        [UInt32] $RetryCount = 5
    )

    # Check if Hyper-V module is present for Hyper-V cmdlets
    if(!(Get-Module -ListAvailable -Name Hyper-V))
    {
        Throw $localizedData.NoHyperVModule
    }
    
    $returnValue = @{
        VMName = $VMName
        RetryIntervalSec = $RetryIntervalSec
        RetryCount = $RetryCount
    }
    $returnValue
}

function Set-TargetResource
{
    param
    (
        [Parameter(Mandatory)]
        [String]$VMName,
        [UInt64]$RetryIntervalSec = 10,
        [UInt32]$RetryCount = 5
    )

    # Check if Hyper-V module is present for Hyper-V cmdlets
    if(!(Get-Module -ListAvailable -Name Hyper-V))
    {
        Throw $localizedData.NoHyperVModule
    }

    $vmIntegrationServicesRunning = $false
    Write-Verbose -Message ($localizedData.CheckGIS -f $VMName)

    for ($count = 0; $count -lt $RetryCount; $count++)
    {
        $gis = Get-VMIntegrationService -VMName $VMName -Name 'Guest Service Interface'
        if ($gis.PrimaryStatusDescription -eq 'OK') {
            Write-Verbose -Message ($localizedData.GISRunning -f $VMName)
            $vmIntegrationServicesRunning = $true
            break
        }
        else
        {
            Write-Verbose -Message ($localizedData.GISNotRunning -f $VMName)
            Write-Verbose -Message ($localizedData.Retry -f $RetryIntervalSec)
            Start-Sleep -Seconds $RetryIntervalSec
        }
    }

    if (!$vmIntegrationServicesRunning)
    {
        throw ($localizedData.CheckError -f $VMName, $RetryIntervalSec)
    }
}

function Test-TargetResource
{
	[OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [String]$VMName,
        [UInt64]$RetryIntervalSec = 10,
        [UInt32]$RetryCount = 5
    )

    # Check if Hyper-V module is present for Hyper-V cmdlets
    if(!(Get-Module -ListAvailable -Name Hyper-V))
    {
        Throw $localizedData.NoHyperVModule
    }
    
    Write-Verbose -Message ($localizedData.CheckGIS -f $VMName)
    $gis = Get-VMIntegrationService -VMName $VMName -Name 'Guest Service Interface'
    if ($gis.PrimaryStatusDescription -eq 'OK') {
        Write-Verbose -Message ($localizedData.GISRunning -f $VMName)
        return $true
    }
    else
    {
        Write-Verbose -Message ($localizedData.GISNotRunning -f $VMName)
        return $false
    }
}

Export-ModuleMember -Function *-TargetResource