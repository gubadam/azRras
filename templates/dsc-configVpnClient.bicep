param vmName string
param location string
param extensionName string = 'VmExtension-Dsc'
param artifactsLocation string
param dnsPrefix string
param domainName string
// param crlFqdn string
param adminUsername string
param adminPassword string
param vpnFqdn string
param adcsHostname string
// param rrasVmPublicIp string
param rrasVmName string

param timestamp string = utcNow('u')

resource rrasVmPublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' existing = {
  name: '${rrasVmName}-pip01'
}

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
        url: '${artifactsLocation}/DSC/out/ConfigVpnClient.zip'
        script: 'ConfigVpnClient.ps1'
        function: 'ConfigVpnClient'
      }
      configurationArguments: {
        VpnFqdn: vpnFqdn
        AdcsVmHostname: adcsHostname
        RrasVmPublicIp: rrasVmPublicIPAddress.properties.ipAddress
        ArtifactsLocation: artifactsLocation
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
