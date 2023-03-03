param vmName string
param location string
param extensionName string = 'VmExtension-Dsc'
param artifactsLocation string
param rrasVmIp string
param adcsVmHostname string
param dnsPrefix string
param adminUsername string
param adminPassword string

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
        url: '${artifactsLocation}/DSC/out/CreateNPS.zip'
        script: 'CreateNPS.ps1'
        function: 'CreateNPS'
      }
      configurationArguments: {
        RrasVmIp: rrasVmIp
        ArtifactsLocation: artifactsLocation
        AdcsVmHostname: adcsVmHostname
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
}
