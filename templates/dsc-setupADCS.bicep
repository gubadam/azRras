param vmName string
param location string
param extensionName string = 'VmExtension-Dsc'
param artifactsLocation string
param dnsPrefix string
param adminUsername string
param adminPassword string
param crlFqdn string

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
        url: '${artifactsLocation}/DSC/out/CreateADCS.zip'
        script: 'CreateADCS.ps1'
        function: 'CreateADCS'
      }
      configurationArguments: {
        DomainName: dnsPrefix
        CrlFqdn: crlFqdn
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
