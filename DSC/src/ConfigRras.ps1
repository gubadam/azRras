Configuration ConfigRras
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [String]$AdcsVmHostname,

        [Parameter(Mandatory)]
        [String]$VpnFqdn,

        [Parameter(Mandatory)]
        [String]$NpsVmIp
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
                $cert = get-certificate -Template "VPNServerAuthentication" -CertStoreLocation "cert:\LocalMachine\My" -SubjectName "CN=$using:VpnFqdn" -DnsName "$using:VpnFqdn","$env:computername" # -Url -Credential $Admincreds
                Set-RemoteAccess -SslCertificate $cert.Certificate
                
                Write-Verbose 'Restarting the RemoteAccess service...'
                Restart-Service -Name RemoteAccess -PassThru
            }
            DependsOn = "[Script]RefreshKerberosTokens"
            PsDscRunAsCredential = $Admincreds
        }

        Script SetupRadiusServer {
            GetScript  = { @{} }
            TestScript = { 
                if (Get-RemoteAccessRadius | Where-Object {$_.ServerName -eq $using:npsVmIp}) { 
                    $true # RADIUS config already exists
                } else {
                    $false
                }
            }
            SetScript = {
                Add-RemoteAccessRadius -ServerName "$($using:npsVmIp)" -SharedSecret 'npsSecret' -Purpose Authentication

                Write-Verbose 'Restarting the RemoteAccess service...'
                Restart-Service -Name RemoteAccess -PassThru
            }
            DependsOn = "[Script]SetupVpnCert"
            PsDscRunAsCredential = $Admincreds
        }

        Script SetupIpAddressRange {
            GetScript  = { @{} }
            TestScript = { 
                $ipAddressRange = (Get-RemoteAccess).VpnConfiguration.IPAddressAssignmentPolicy.IPAddressRange
                if ($ipAddressRange.StartIPAddress -eq '172.20.0.1' -and $ipAddressRange.EndIPAddress -eq '172.20.0.254') {
                    $true # VPN client IP address range is already configured
                } else {
                    $false
                }
                Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
            }
            SetScript = {
                Set-VpnIPAddressAssignment -IPAssignmentMethod StaticPool -IPAddressRange "172.20.0.1","172.20.0.254"
            }
            DependsOn = "[Script]SetupRadiusServer"
            PsDscRunAsCredential = $Admincreds
        }
    }
}