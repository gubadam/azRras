Configuration CreateRRAS
{
    param
    (
        [System.Management.Automation.PSCredential]$Admincreds
    )

    Import-DscResource -ModuleName ComputerManagementDsc

    Node localhost
    {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        Script InstallRras {
            GetScript  = { @{} }
            TestScript = {
                $InstallState = Get-WindowsFeature DirectAccess-VPN | Select-Object -ExpandProperty InstallState
                If ($InstallState -ne 'Installed') { $false } else { $true }
            }
            SetScript  = {
                Install-WindowsFeature -Name DirectAccess-VPN -IncludeManagementTools
                Install-WindowsFeature -Name web-mgmt-console
            }
        }

        PendingReboot AfterInstallFeature {
            Name      = 'AfterInstallFeature'
            DependsOn = '[Script]InstallRras'
        }
        
        Script ConfigRras {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript  = {
                if ((Get-RemoteAccess).VpnStatus -ne "Installed") { 
                    Install-RemoteAccess -VpnType VPN -Legacy
                }
                Start-Sleep -Seconds 10 # wait for RemoteAccess server to start

                Set-RemoteAccessAccounting -EnableAccountingType Inbox
                Set-VpnAuthProtocol -UserAuthProtocolAccepted @('EAP', 'Certificate')
                Restart-Service -Name RemoteAccess

                Invoke-Command -ScriptBlock { netsh.exe ras aaaa set authentication provider = radius }
                Invoke-Command -Scriptblock { netsh.exe ras aaaa set accounting provider = radius }

                Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter 'system.webServer/defaultDocument' -Name 'Enabled' -Value 'False'
                Remove-Item -Path C:\Inetpub\wwwroot\iisstart.*
            }
            DependsOn  = '[PendingReboot]AfterInstallFeature','[Script]InstallRras'
        }

        PendingReboot AfterConfig {
            Name      = 'AfterConfig'
            DependsOn = '[Script]ConfigRras'
        }
    }
}