Configuration CreateNPS
{
    param
    (
        [System.Management.Automation.PSCredential]$Admincreds,
        [String]$RrasVmIp,
        [String]$ArtifactsLocation,
        [String]$AdcsVmHostname
    )

    Import-DscResource -ModuleName ComputerManagementDsc

    Node localhost
    {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        Script InstallNps {
            GetScript  = { @{} }
            TestScript = {
                $InstallState = Get-WindowsFeature NPAS | Select-Object -ExpandProperty InstallState
                If ($InstallState -ne 'Installed') { $false } else { $true }
            }
            SetScript  = {
                Install-WindowsFeature NPAS -IncludeManagementTools
                auditpol.exe /set /subcategory:"Network Policy Server" /success:enable /failure:enable
                $OSVersion = (Get-CimInstance 'Win32_OperatingSystem').Version
                if ($OSVersion -eq '10.0.17763') {
                    sc.exe sidtype IAS unrestricted
                }
            }
        }

        PendingReboot AfterConfig {
            Name      = 'AfterConfig'
            DependsOn = '[Script]InstallNps'
        }

        Script ImportNpsConfigTemplate {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript  = {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri "$using:ArtifactsLocation/DSC/npsConfig/npsConfig.xml" -UseBasicParsing -OutFile './npsConfig.xml'
                Import-NpsConfiguration -Path .\npsConfig.xml
            }
            DependsOn = '[PendingReboot]AfterConfig'
        }

        Script RegisterNpsInAd {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript  = {
                netsh nps add registeredserver
            }
            DependsOn = '[Script]ImportNpsConfigTemplate'
            PsDscRunAsCredential = $Admincreds
        }

        Script AddRadiusClient {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript  = {
                New-NpsRadiusClient -Name vpn -Address $using:RrasVmIp -SharedSecret 'npsSecret'
            }
            DependsOn = '[Script]RegisterNpsInAd'
        }

        Script ImportRootCa {
            GetScript  = { @{
                Certs = (get-childitem "\\$using:AdcsVmHostname\c$\inetpub\wwwroot\CertEnroll" | Where-Object {$_.name -like "*.crt"}).FullName
            } }
            TestScript = { $false }
            SetScript = {
                $rootCaCerts = get-childitem "\\$using:AdcsVmHostname\c$\Windows\System32\CertSrv\CertEnroll" | Where-Object {$_.name -like "*.crt"}
                $rootCaCerts | Sort-Object -Property lastwritetime -Descending | ForEach-Object {
                    Import-Certificate -FilePath $_.FullName -CertStoreLocation "Cert:\LocalMachine\Root"
                    certutil -enterprise -addstore NTAuth "$($_.fullname)"
                }
                certutil -pulse
            }
            PsDscRunAsCredential = $Admincreds
            DependsOn = "[Script]AddRadiusClient"
        }

        Script RefreshKerberosTokens {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript = {
                gpupdate /force
                Start-Sleep -Seconds 1
                klist -li 0:0x3e7 purge
                Start-Sleep -Seconds 1
            }
            DependsOn = "[Script]ImportRootCa"
        }

        Script SetupNpsCert {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript = {
                get-certificate -Template "VPNServerAuthentication" -CertStoreLocation "cert:\LocalMachine\My" -SubjectName "CN=$env:computername" -DnsName "$env:computername"
                Restart-Service IAS
            }
            DependsOn = "[Script]RefreshKerberosTokens"
            PsDscRunAsCredential = $Admincreds
        }
    }
}