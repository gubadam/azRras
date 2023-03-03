Configuration CreateADCS
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [String]$CrlFqdn
    )

    Import-DscResource -ModuleName xAdcsDeployment

    Node localhost
    {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        WindowsFeature ADCSCA {
            Name = 'ADCS-Cert-Authority'
            Ensure = 'Present'
        }

        WindowsFeature ADDSTools {
            Ensure    = "Present"
            Name = "RSAT-AD-PowerShell"
        }
        
        xADCSCertificationAuthority ConfigCA
        {
            Ensure = 'Present'
            Credential = $Admincreds
            CAType = 'EnterpriseRootCA'
            CACommonName = "$DomainName Root Certification Authority"
            ValidityPeriod = 'Years'
            ValidityPeriodUnits = 20
            CryptoProviderName = 'RSA#Microsoft Software Key Storage Provider'
            HashAlgorithmName = 'SHA256'
            KeyLength = 4096
            DependsOn = '[WindowsFeature]ADCSCA' 
        }

        WindowsFeature RSAT-ADCS 
        { 
            Ensure = 'Present' 
            Name = 'RSAT-ADCS' 
            DependsOn = '[WindowsFeature]ADCSCA' 
        } 

        WindowsFeature Web-Mgmt-Tools
        { 
            Ensure = 'Present' 
            Name = 'Web-Mgmt-Tools'
        } 

        WindowsFeature RSAT-ADCS-Mgmt 
        { 
            Ensure = 'Present' 
            Name = 'RSAT-ADCS-Mgmt' 
            DependsOn = '[WindowsFeature]ADCSCA'
        }

        WindowsFeature ADCS-Online-Cert
        {
            Ensure = 'Present'
            Name   = 'ADCS-Online-Cert'
        }

        xAdcsOnlineResponder OnlineResponder
        {
            Ensure           = 'Present'
            IsSingleInstance = 'Yes'
            Credential       = $Admincreds
            DependsOn        = '[WindowsFeature]ADCS-Online-Cert'
        }

        WindowsFeature ADCS-Web-Enrollment
        {
            Ensure = 'Present'
            Name   = 'ADCS-Web-Enrollment'
            DependsOn = '[xADCSCertificationAuthority]ConfigCA'
        }

        xAdcsWebEnrollment WebEnrollment
        {
            Ensure           = 'Present'
            IsSingleInstance = 'Yes'
            Credential       = $Admincreds
            DependsOn        = '[WindowsFeature]ADCS-Web-Enrollment'
        }

        Script ConfigureCRL {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript = {
                $certEnrollPath = "C:\inetpub\wwwroot\CertEnroll"
                if ($false -eq (test-path $certEnrollPath)) { mkdir $certEnrollPath }

                if ((get-CACrlDistributionPoint | Where-Object {$_.uri -eq "C:\inetpub\wwwroot\CertEnroll\<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl"}).count -eq 0) {
                    Add-CACrlDistributionPoint -Uri "C:\inetpub\wwwroot\CertEnroll\<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl" -PublishToServer -PublishDeltaToServer
                }

                if ((get-CACrlDistributionPoint | Where-Object {$_.uri -eq "http://<ServerDNSName>/CertEnroll/<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl"}).count -eq 1) {
                    remove-CACrlDistributionPoint -Uri "http://<ServerDNSName>/CertEnroll/<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl"
                }
                
                if ((get-CACrlDistributionPoint | Where-Object {$_.uri -eq "file://<ServerDNSName>/CertEnroll/<CAName><CRLNameSuffix><DeltaCRLAllowed>.crl"}).count -eq 0) {
                    add-CACrlDistributionPoint -Uri "file://<ServerDNSName>/CertEnroll/<CAName><CRLNameSuffix><DeltaCRLAllowed>.crl" -AddToCertificateCdp
                }

                if ((get-CACrlDistributionPoint | Where-Object {$_.uri -eq "http://$using:CrlFqdn/CertEnroll/<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl"}).count -eq 0) {
                    add-CACrlDistributionPoint -Uri "http://$using:CrlFqdn/CertEnroll/<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl" -AddToCertificateCdp
                }
                
                if ((get-CACrlDistributionPoint | Where-Object {$_.uri -eq "ldap:///CN=<CATruncatedName>,CN=AIA,CN=Public Key Services,CN=Services,<ConfigurationContainer><CAObjectClass>"}).count -eq 1) {
                    remove-CACrlDistributionPoint -Uri "ldap:///CN=<CATruncatedName>,CN=AIA,CN=Public Key Services,CN=Services,<ConfigurationContainer><CAObjectClass>"
                }

                if ((get-CAAuthorityInformationAccess | Where-Object {$_.uri -eq "ldap:///CN=<CATruncatedName>,CN=AIA,CN=Public Key Services,CN=Services,<ConfigurationContainer><CAObjectClass>"}).count -eq 1) {
                    Remove-CAAuthorityInformationAccess -Uri "ldap:///CN=<CATruncatedName>,CN=AIA,CN=Public Key Services,CN=Services,<ConfigurationContainer><CAObjectClass>"
                }

                if ((Get-CAAuthorityInformationAccess | Where-Object {$_.uri -eq "http://$using:CrlFqdn/CertEnroll/<ServerDNSName>_<CAName><CertificateName>.crt"}).count -eq 0) {
                    Add-CAAuthorityInformationAccess -Uri "http://$using:CrlFqdn/CertEnroll/<ServerDNSName>_<CAName><CertificateName>.crt" -AddToCertificateAia
                }

                if ((Get-CAAuthorityInformationAccess | Where-Object {$_.uri -eq "http://$using:CrlFqdn/ocsp"}).count -eq 0) {
                    Add-CAAuthorityInformationAccess -Uri "http://$using:CrlFqdn/ocsp" -AddToCertificateOcsp
                }

                # Renew CA cert with new CRL and AIA info
                certutil -renewCert ReuseKeys
                start-sleep -second 1
                Copy-Item -Path "C:\Windows\System32\CertSrv\CertEnroll\*" -Destination "C:\inetpub\wwwroot\CertEnroll" -Recurse
                
                # allow double-escaping for delta CRLs
                C:\Windows\system32\inetsrv\AppCmd.exe set config "Default Web Site" -section:system.webServer/security/requestFiltering -allowDoubleEscaping:true

                stop-service certsvc
                start-service certsvc
            }
            DependsOn = '[xAdcsWebEnrollment]WebEnrollment', '[WindowsFeature]ADCSCA', '[xAdcsOnlineResponder]OnlineResponder'
            Credential = $Admincreds
        }

        Script PublishRootCaInAdds {
            GetScript  = { @{} }
            TestScript = { $false }
            SetScript = {
                $caCerts = Get-ChildItem "C:\Windows\System32\CertSrv\CertEnroll" | Where-Object {$_.name -like "*.crt"} 
                $caCerts | ForEach-Object {
                    certutil -dspublish -f $_.FullName ntauthca
                    Copy-Item -Path $_.FullName -Destination 'C:\inetpub\wwwroot\CertEnroll'
                    start-sleep -second 1
                }
                stop-service certsvc
                start-service certsvc
            }
            DependsOn = '[Script]ConfigureCRL'
            Credential = $Admincreds
        }
        
    }
}