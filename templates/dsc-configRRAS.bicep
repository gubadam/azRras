param vmName string
param location string
param extensionName string = 'VmExtension-Dsc'
param artifactsLocation string
param dnsPrefix string
// param crlFqdn string
param adminUsername string
param adminPassword string
param vpnFqdn string
param adcsHostname string
param npsVmIp string

param timestamp string = utcNow('u')

resource vm 'Microsoft.Compute/virtualMachines@2020-12-01' existing = {
  name: vmName
}

resource dscModules 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: vm
  name: extensionName
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.9'
    autoUpgradeMinorVersion: true
    forceUpdateTag: timestamp
    settings: {
      configuration: {
        url: '${artifactsLocation}/DSC/out/ConfigRras.zip'
        script: 'ConfigRras.ps1'
        function: 'ConfigRras'
      }
      configurationArguments: {
        DomainName: dnsPrefix
        VpnFqdn: vpnFqdn
        AdcsVmHostname: adcsHostname
        NpsVmIp: npsVmIp
      }
    }
    protectedSettings: {
      configurationArguments: {
        AdminCreds: {
          UserName: '${dnsPrefix}\\${adminUsername}'
          Password: adminPassword
        }
      }
    }
  }
}
