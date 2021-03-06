# Fallback message strings in en-US
DATA localizedData
{
ConvertFrom-StringData @'    
    NoHyperVModule=Hyper-V PowerShell Module not found.
    MoreThanOneAdapter=More than one adapater with the same name found.
    GetNetConfig=Retrieving network configuration.
    GetNetAdapter=Retrieving network adapter information.
    SubnetMust=IPAddress and Subnet values must be provided for static IP configuration.
    SetNetConfigDHCP=Setting Network Configuration to DHCP.
    SetNetConfigStatic=Setting network configuration to static.
    NetStaticSuccess=Staic IP Address configuration successful.
    NetStaticFailure=Static IP address configuration failed.
    NetDHCPSuccess=DHCP configuration successful.
    NetDHCPFailure=DHCP configuration failed.
    GWDoesnotExist=Default Gateway Configuration does not exist as required. It will be configured.
    DnsDoesnotExist=DNS configuration does not exist as required. It will be configured.
    ConfigurationExists=IP configuration exists as required.
    ConfigurationDoesnotExist=Configuration does not exist as required. It will be configured.
    StaticRequested=Static IP configuration requested but found DHCP enabled.
    DHCPExists=DHCP configuration exists as required.
    DHCPDoesnotExist=DHCP Configuration is not enabled as required.
    NetAdapterDoesnotExist=Specified Network Adapter does not exist.
    VMNotRunning=Specified VM is not in running state.
'@    
}

if (Test-Path "$PSScriptRoot\$PSCulture")
{
    Import-LocalizedData LocalizedData -filename "cVMIPAddress.psd1" -BaseDirectory "$PSScriptRoot\$PSCulture"
}

function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory)]
        [String]$Id,
        
        [Parameter(Mandatory)]
        [String]$vmName,

        [Parameter(Mandatory)]
        [String]$netAdapterName,

        [Parameter(Mandatory)]
        [String]$IPAddress
    )

    # Check if Hyper-V module is present for Hyper-V cmdlets
    if(!(Get-Module -ListAvailable -Name Hyper-V))
    {
        Throw $localizedData.NoHyperVModule
    }
    
    $Configuration = @{
        VMName = $VMName
        NetAdapterName = $netAdapterName
    }
    
    Write-Verbose $localizedData.GetNetConfig
    $NetAdapter = Get-VMNetworkConfiguration -vmName $vmName -netAdapterName $netAdapterName -Verbose
    
    if (-not ($NetAdapter.Count -gt 1)) {
        $Configuration.Add('IPAddress',$NetAdapter.IPAddresses)
        $Configuration.Add('Subnet',$NetAdapter.Subnets)
        $Configuration.Add('DefaultGateway',$NetAdapter.DefaultGateways)
        $Configuration.Add('DnsServer',$NetAdapter.DnsServers)
    } else {
        throw $localizedData.MoreThanOneAdapter
    }
    
    return $Configuration
}

function Set-TargetResource
{
    param
    (
        [Parameter(Mandatory)]
        [String] $Id,
        
        [Parameter(Mandatory)]
        [String]$vmName,

        [Parameter(Mandatory)]
        [String]$netAdapterName,

        [Parameter(Mandatory)]
        [String]$IPAddress,

        [Parameter()]
        [String]$Subnet,

        [Parameter()]
        [String]$DefaultGateway,

        [Parameter()]
        [String]$DNSServer
    )

    # Check if Hyper-V module is present for Hyper-V cmdlets
    if(!(Get-Module -ListAvailable -Name Hyper-V))
    {
        Throw $localizedData.NoHyperVModule
    }
    
    Write-Verbose $localizedData.GetNetAdapter
    $netAdapter = Get-VMNetworkAdapter -VMName $vmName -Name $netAdapterName -ErrorAction SilentlyContinue
    if ($netAdapter -and $netAdapter.Count -eq 1) {
        if ($IPAddress -eq 'DHCP') {
            Write-Verbose $localizedData.SetNetConfigDHCP
            $arguments = @{
                'NetworkAdapterName' = $netAdapterName
                'VmName' = $vmName
                'dhcp' = $true
            }
            $returnValue = Set-VMNetworkConfiguration @arguments -Verbose
            if ($returnValue) {
                Write-Verbose $localizedData.NetDHCPSuccess
            } else {
                throw $localizedData.NetDHCPFailure
            }
        } else {
            if (-not $Subnet) {
                throw $localizedData.SubnetMust 
            } else {
                Write-Verbose $localizedData.SetNetConfigStatic
                $arguments = @{
                    'NetworkAdapterName' = $netAdapterName
                    'VmName' = $vmName
                    'dhcp' = $false
                    'IPAddress' = $IPAddress
                    'Subnet' = $Subnet
                    'DefaultGateway' = $DefaultGateway
                    'DnsServer' = $DNSServer
                }
                $returnValue = Set-VMNetworkConfiguration @arguments -Verbose
                if ($returnValue) {
                    Write-Verbose $localizedData.NetStaticSuccess
                } else {
                    throw $localizedData.NetStaticFailure
                }
            }
        }
    }
}

function Test-TargetResource
{
	[OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [String] $Id,
                
        [Parameter(Mandatory)]
        [String]$vmName,

        [Parameter(Mandatory)]
        [String]$netAdapterName,

        [Parameter(Mandatory)]
        [String]$IPAddress,

        [Parameter()]
        [String]$Subnet,

        [Parameter()]
        [String]$DefaultGateway,

        [Parameter()]
        [String]$DNSServer
    )

    # Check if Hyper-V module is present for Hyper-V cmdlets
    if(!(Get-Module -ListAvailable -Name Hyper-V))
    {
        Throw $localizedData.NoHyperVModule
    }
    
    Write-Verbose $localizedData.GetNetConfig
    $NetAdapter = Get-VMNetworkConfiguration -vmName $vmName -netAdapterName $netAdapterName -Verbose

    if ($NetAdapter) {
        if ($IPAddress -ne 'DHCP') {
            if (-not $Subnet) {
                throw $localizedData.SubnetMust
            }
            if (-not $NetAdapter.DHCPEnabled) {
                if (($NetAdapter.IPAddresses -contains $IPAddress) -and ($NetAdapter.Subnets -contains $Subnet)) {
                    if ($DefaultGateway) {
                        if (-not ($NetAdapter.DefaultGateways -contains $DefaultGateway)) {
                            Write-Verbose $localizedData.GWDoesnotExist
                            return $false
                        }
                    }

                    if ($DnsServer) {
                        if (-not ($NetAdapter.DnsServers -contains $DnsServer)) {
                            Write-Verbose $localizedData.DnsDoesnotExist
                            return $false
                        }
                    }
                    Write-Verbose $localizedData.ConfigurationExists
                    return $true
                } else {
                    Write-Verbose $localizedData.ConfigurationDoesnotExist
                    return $false
                }
            } else {
                Write-Verbose $localizedData.StaticRequested
                return $false
            }
        } else {
            if ($NetAdapter.DHCPEnabled) {
                Write-Verbose $localizedData.DHCPExists
                return $true
            } else {
                Write-Verbose $localizedData.DHCPDoesnotExist
                return $false
            }
        }
    } else {
        throw $localizedData.NetAdapterDoesnotExist
    }
}

Function Get-VMNetworkConfiguration {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory)]
        [ValidateScript({
            Get-VM -Name $_
        }
        )]
        [String]$vmName,

        [Parameter(Mandatory)]
        [String]$netAdapterName
          
    )

    $vmObject = Get-CimInstance -Namespace 'root\virtualization\v2' -Class 'Msvm_ComputerSystem' | Where-Object { $_.ElementName -eq 'MABS-01' }

    if ($vmObject.EnabledState -ne 2) {
        throw $localizedData.VMNotRunning
    } else {
        $vmSetting = Get-CimAssociatedInstance -InputObject $vmObject -ResultClassName 'Msvm_VirtualSystemSettingData'
        $netAdapter = Get-CimAssociatedInstance -InputObject $vmSetting -ResultClassName 'Msvm_SyntheticEthernetPortSettingData' | Where-Object { $_.ElementName -eq $netAdapterName }
        if ($netadapter) {
            foreach ($adapter in $netAdapter) {
                $NetConfig = Get-CimAssociatedInstance -InputObject $adapter -ResultClassName 'Msvm_GuestNetworkAdapterConfiguration' | Select IPAddresses, Subnets, DefaultGateways, DNSServers, DHCPEnabled, @{Name="AdapterName";Expression={$adapter.ElementName}}
            }
        } else {
            Write-Warning $localizedData.NetAdapterDoesnotExist
            return $false
        }
    }
    
    return $NetConfig
}

Function Set-VMNetworkConfiguration {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String]$NetworkAdapterName,

        [Parameter(Mandatory)]
        [String]$VMName,

        [Parameter()]
        [String[]]$IPAddress=@(),

        [Parameter()]
        [String[]]$Subnet=@(),

        [Parameter()]
        [String[]]$DefaultGateway=@(),

        [Parameter()]
        [String[]]$DNSServer=@(),

        [Parameter()]
        [Switch]$Dhcp
    )

    $NetworkAdapter = Get-VMNetworkAdapter -VMName $VMName -Name $NetworkAdapterName -Verbose -ErrorAction Stop
    $VM = Get-CimInstance -Namespace 'root\virtualization\v2' -Class 'Msvm_ComputerSystem' | Where-Object { $_.ElementName -eq $NetworkAdapter.VMName } 
    $VMSettings = Get-CimAssociatedInstance -InputObject $vm -ResultClassName 'Msvm_VirtualSystemSettingData' | Where-Object { $_.VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' }    
    $VMNetAdapter = Get-CimAssociatedInstance -InputObject $VMSettings -ResultClassName 'Msvm_SyntheticEthernetPortSettingData' | Where { $_.ElementName -eq $NetworkAdapter.Name }

    $NetworkSettings = Get-CimAssociatedInstance -InputObject $VMNetAdapter -ResultClassName 'Msvm_GuestNetworkAdapterConfiguration'
    $NetworkSettings.psbase.CimInstanceProperties['ipaddresses'].Value = $IPAddress
    $NetworkSettings.psbase.CimInstanceProperties['Subnets'].Value = $Subnet
    $NetworkSettings.psbase.CimInstanceProperties['DefaultGateways'].Value = $DefaultGateway
    $NetworkSettings.psbase.CimInstanceProperties['DNSServers'].Value = $DNSServer
    $NetworkSettings.psbase.CimInstanceProperties['ProtocolIFType'].Value = 4096

    if ($dhcp) {
        $NetworkSettings.psbase.CimInstanceProperties['DHCPEnabled'].Value = $true
    } else {
        $NetworkSettings.psbase.CimInstanceProperties['DHCPEnabled'].Value = $false
    }

    $cimSerializer = [Microsoft.Management.Infrastructure.Serialization.CimSerializer]::Create()
    $serializedInstance = $cimSerializer.Serialize($NetworkSettings, [Microsoft.Management.Infrastructure.Serialization.InstanceSerializationOptions]::None)
    $embeddedInstanceString = [System.Text.Encoding]::Unicode.GetString($serializedInstance)

    $Service = Get-CimInstance -Class "Msvm_VirtualSystemManagementService" -Namespace "root\virtualization\v2"

    $setIP = Invoke-CimMethod -InputObject $Service -MethodName SetGuestNetworkAdapterConfiguration -Arguments @{'ComputerSystem'=$VM;'NetworkConfiguration'=,$embeddedInstanceString} -Verbose

    if ($setip.ReturnValue -eq 4096) {
        $job=[WMI]$setip.job 

        while ($job.JobState -eq 3 -or $job.JobState -eq 4) {
            start-sleep 1
            $job=[WMI]$setip.job
        }

        if ($job.JobState -eq 7) {
            return $true
        } else {
            throw $job.GetError()
        }
    } elseif($setip.ReturnValue -eq 0) {
        return $true       
    }
}

Export-ModuleMember -Function *-TargetResource