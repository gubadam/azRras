Configuration SetupAdGroups
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [String]$RrasVmHostname,

        [Parameter(Mandatory)]
        [String]$NpsVmHostname
    )

    Node localhost
    {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        Script VpnAdGroups {
            GetScript  = { @{} }
            TestScript = { $false}
            SetScript  = {
                $adGroups = @(
                    "VPN Users",
                    "VPN Servers",
                    "NPS Servers"
                )
                foreach ($adGroup in $adGroups) {
                    try {
                        Get-AdGroup $adGroup
                    } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                        New-ADGroup -Name $adGroup -GroupCategory Security -GroupScope Global
                    }                    
                }

                Set-AdUser $using:Admincreds.UserName -EmailAddress "$($using:Admincreds.UserName)@$($using:DomainName)"
                Add-AdGroupMember "VPN Servers" -Members (Get-ADComputer $using:rrasvmhostname)
                Add-AdGroupMember "VPN Servers" -Members (Get-ADComputer $using:npsvmhostname)
                Add-AdGroupMember "NPS Servers" -Members (Get-ADComputer $using:npsvmhostname)
                Add-AdGroupMember "VPN Users" -Members $using:Admincreds.UserName
            }
        }
    }
}