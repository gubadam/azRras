Configuration CreateADPDC
{ 
    param 
    ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount = 20,
        [Int]$RetryIntervalSec = 30
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory, xNetworking

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface = Get-NetAdapter | Where-Object Name -Like "Ethernet*" | Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        WindowsFeature DNS { 
            Ensure = "Present"
            Name   = "DNS"
        }

        Script GuestAgent
        {
            SetScript  = {
                Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\WindowsAzureGuestAgent' -Name DependOnService -Type MultiString -Value DNS
                Write-Verbose -Verbose "GuestAgent depends on DNS"
            }
            GetScript  = { @{} }
            TestScript = { $false }
            DependsOn  = "[WindowsFeature]DNS"
        }

        Script EnableDNSDiags {
            SetScript  = { 
                Set-DnsServerDiagnostics -All $true
                Write-Verbose -Verbose "Enabling DNS client diagnostics"
            }
            GetScript  = { @{} }
            TestScript = { $false }
            DependsOn  = "[WindowsFeature]DNS"
        }

        WindowsFeature DnsTools {
            Ensure    = "Present"
            Name      = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn      = "[WindowsFeature]DNS"
        }

        WindowsFeature ADDSInstall { 
            Ensure    = "Present" 
            Name      = "AD-Domain-Services"
            DependsOn = "[WindowsFeature]DNS" 
        } 

        WindowsFeature ADDSTools {
            Ensure    = "Present"
            Name      = "RSAT-ADDS-Tools"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        WindowsFeature ADAdminCenter {
            Ensure    = "Present"
            Name      = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        xADDomain FirstDS 
        {
            DomainName                    = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath                  = "C:\NTDS"
            LogPath                       = "C:\NTDS"
            SysvolPath                    = "C:\SYSVOL"
            DependsOn                     = @("[WindowsFeature]ADDSInstall")
        } 
    }
} 
