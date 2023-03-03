Configuration ConfigVpnClient
{
    param
    (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [String]$AdcsVmHostname,

        [Parameter(Mandatory)]
        [String]$VpnFqdn,

        [Parameter(Mandatory)]
        [String]$RrasVmPublicIp,

        [Parameter(Mandatory)]
        [String]$ArtifactsLocation
    )

    Node localhost
    {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        Script ImportRootCa {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript = {
                $rootCaCerts = get-childitem "\\$using:AdcsVmHostname\c$\Windows\System32\CertSrv\CertEnroll"
                $rootCaCerts | Where-Object {$_.name -like "*.crt"} | ForEach-Object {
                    Import-Certificate -FilePath $_.FullName -CertStoreLocation "Cert:\LocalMachine\Root"
                }
            }
            PsDscRunAsCredential = $Admincreds
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

        Script SetupVpnCert {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript = {
                get-certificate -Template "VPNUserAuthentication" -CertStoreLocation "cert:\CurrentUser\My"
            }
            DependsOn = "[Script]RefreshKerberosTokens"
            PsDscRunAsCredential = $Admincreds
        }

        Script SetupDummyNameResolution {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript = {
                Add-Content -Path $env:windir\System32\drivers\etc\hosts -Value "`n$using:RrasVmPublicIp`t$using:VpnFqdn" -Force
            }
            DependsOn = "[Script]SetupVpnCert"
            PsDscRunAsCredential = $Admincreds
        }

        Script SetupVpnConnection {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript = {
                if ((Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\Sstpsvc\Parameters" -Name "NoCertRevocationCheck" -ErrorAction SilentlyContinue) -eq $null) {
                    New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\Sstpsvc\Parameters" -Name "NoCertRevocationCheck" -Value 1 -PropertyType DWORD
                }
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri "$using:ArtifactsLocation/DSC/vpnConfig/eapConfig.xml" -UseBasicParsing -OutFile './eapConfig.xml'
                if ((Get-VpnConnection).name -contains $using:VpnFqdn) {
                    rasdial $vpnfqdn /disconnect
                    Remove-VpnConnection -Name $using:VpnFqdn -Confirm:$false -Force
                }
                Add-VpnConnection -Name $using:VpnFqdn -ServerAddress $using:VpnFqdn -TunnelType Sstp -AuthenticationMethod Eap -EapConfigXmlStream (get-content '.\eapConfig.xml') -SplitTunneling
                rasdial $using:VpnFqdn
                # rasdial $VpnFqdn /disconnect
            }
            DependsOn = "[Script]SetupDummyNameResolution"
            PsDscRunAsCredential = $Admincreds
        }
    }
}

