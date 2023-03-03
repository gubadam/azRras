# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Configuration InstallDSCModules {

    param ( 
        [String[]]$Name,
        [System.Management.Automation.PSCredential]$Admincreds
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Script ConfigureScriptRepository {
        SetScript = {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            try {
                If ( (Get-PackageProvider -Name Nuget -ListAvailable -ErrorAction Stop ).Version -le 2.8.5.208 ) {
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force
                }
            } catch {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force
            }
        
            if ((Get-PSRepository -Name 'PSGallery').InstallationPolicy -eq 'Untrusted' ) {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            }
        }
        TestScript = { 
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            if (((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -eq 'Trusted') -and ((Get-PackageProvider -Name Nuget -ListAvailable -ErrorAction SilentlyContinue).Version -ge 2.8.5.208)) {
                $true
            } else {
                $false
            }
        }
        GetScript = { @{ Result = "" + ((Get-PSRepository -Name PSGallery) + " | " + (Get-PackageProvider -Name Nuget -ListAvailable -ErrorAction Stop)) } }
    }

    foreach ($moduleName in $Name) {
        Script "InstallModule-$moduleName" {
            GetScript = {
                $state = [hashtable]::new()
                $state.Module_Name = $using:moduleName
                $Module = Get-Module -Name $using:moduleName -ListAvailable -ErrorAction Ignore
                $Module
            }
    
            SetScript = {
                try {
                    $arguments = @{
                        Name = $using:moduleName
                        ErrorAction = "Stop"
                    }
                    Find-Module @arguments
                }
                catch {
                    Write-Error -ErrorRecord $_
                    throw $_
                }
    
                try {
                    $arguments = @{
                        Name = $using:moduleName
                        Force = $true
                    }
                    Install-Module @arguments
                }
                catch {
                    Write-Error -ErrorRecord $_
                }
            }
        
            TestScript = {
                $modules = @()
                $modules += @(Get-Module -Name $using:moduleName -ListAvailable -ErrorAction Ignore)
        
                if ($modules.Name -contains $using:moduleName) {
                    return $true
                } else {
                    return $false
                }
            }
        }
    }
}
