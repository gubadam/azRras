#Requires -module ComputerManagementDsc

configuration JoinDomain 
{ 
    param 
    ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds
    )

    $env:PSModulePath += ";$PSScriptRoot"
    Import-DscResource -Module ComputerManagementDsc

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        Script RenewIpLease {
            SetScript = {
                ipconfig /renew
            }
            GetScript  = { @{} }
            TestScript = { $false }
        }

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        Computer JoinDomain {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = "[Script]RenewIpLease"
        }
    }
} 
