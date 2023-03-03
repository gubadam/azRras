Configuration SetupCertTemplates
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [String]$ArtifactsLocation
    )

    Import-Module ADCSTemplate

    Node localhost
    {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        Script CertTemplates {
            GetScript  = { @{} }
            TestScript = { 
                if ((Get-ADCSTemplate -DisplayName "VPN User Authentication") -and (Get-ADCSTemplate -DisplayName "VPN Server Authentication")) {
                    $true
                } else {
                    $false
                }
            }
            SetScript  = {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri "$using:ArtifactsLocation/DSC/certTemplates/vpnServerAuthentication.json" -UseBasicParsing -OutFile './vpnServerAuthentication.json'
                Invoke-WebRequest -Uri "$using:ArtifactsLocation/DSC/certTemplates/vpnUserAuthentication.json" -UseBasicParsing -OutFile './vpnUserAuthentication.json'

                New-ADCSTemplate -JSON (Get-Content ".\vpnUserAuthentication.json" -raw) -DisplayName "VPN User Authentication" -Identity "VPN Users" -AutoEnroll -Publish
                New-ADCSTemplate -JSON (Get-Content ".\vpnServerAuthentication.json" -raw) -DisplayName "VPN Server Authentication" -Identity "VPN Servers" -Autoenroll -Publish

                # complete VPN User Auth template
                $template =  [adsi]"LDAP://CN=VPNUserAuthentication,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,DC=ad,DC=local"
                $template.Put('msPKI-RA-Application-Policies',"msPKI-Asymmetric-Algorithm``PZPWSTR``RSA``msPKI-Hash-Algorithm``PZPWSTR``SHA1``msPKI-Key-Usage``DWORD``16777215``msPKI-Symmetric-Algorithm``PZPWSTR``3DES``msPKI-Symmetric-Key-Length``DWORD``168``")
                $template.Put('pKIDefaultCSPs',"1,Microsoft Software Key Storage Provider")
                $template.SetInfo()
                
                gpupdate /force
                net stop "certsvc"
                net start "certsvc"
            }
            PsDscRunAsCredential = $Admincreds
        }

        Script PublishCA {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript  = {
                $caCerts = Get-ChildItem "C:\Windows\System32\CertSrv\CertEnroll" | Where-Object {$_.name -like "*.crt"} 
                $caCerts | ForEach-Object {
                    certutil -dspublish -f $_.FullName ntauthca
                    Copy-Item -Path $_.FullName -Destination 'C:\inetpub\wwwroot\CertEnroll'
                    start-sleep -second 1
                }
                stop-service certsvc
                start-service certsvc
            }
            PsDscRunAsCredential = $Admincreds
            DependsOn = '[Script]CertTemplates'
        }

        # reboot required for aquiring updated group membership for cert enrollment
        Script Reboot {
            TestScript = {
                return (Test-Path HKLM:\SOFTWARE\AzRras\RebootKey)
            }
            SetScript = {
                New-Item -Path HKLM:\SOFTWARE\AzRras\RebootKey -Force
                $global:DSCMachineStatus = 1 
            }
            GetScript = { return @{result = 'result'}}
            DependsOn = '[Script]PublishCA'
        }
    }
}