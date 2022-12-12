param VnetParameters object = {
  vnetName: 'vnet-rras-01'
  vnetIPRange: '10.0.0.0/16'
  subnetName: 'snet-rras-01'
  subnetIPRange: '10.0.0.0/24'
}
param ADDSParameters object = {
  vmName: 'vmAdds'
  dnsPrefix: 'ad.local'
  ipAddress: '10.0.0.4'
  adminUsername: 'adminUsername'
  adminPassword: 'adminPassword'
}
param ADCSParameters object = {
  vmName: 'vmAdcs'
  ipAddress: '10.0.0.5'
  adminUsername: 'adminUsername'
  adminPassword: 'adminPassword'
}
param NPSParameters object = {
  vmName: 'vmNps'
  ipAddress: '10.0.0.6'
  adminUsername: 'adminUsername'
  adminPassword: 'adminPassword'
}
param RRASParameters object = {
  vmName: 'vmRras'
  ipAddress: '10.0.0.7'
  adminUsername: 'adminUsername'
  adminPassword: 'adminPassword'
}

param artifactsLocation string

param location string = resourceGroup().location

module deployVnet 'templates/vnet.bicep' = {
  name: '${az.deployment().name}-vnet'
  params: {
    vnetName: VnetParameters.vnetName
    vnetIPRange: VnetParameters.vnetIPRange
    snetName: VnetParameters.subnetName
    snetIPRange: VnetParameters.subnetIPRange
    location: location
  }
}

module deployVmADDS 'templates/vm.bicep' = {
  name: '${az.deployment().name}-vmADDS'
  params: {
    vmName: ADDSParameters.vmName
    vmIp: ADDSParameters.ipAddress
    snetId: resourceId('Microsoft.Network/virtualNetworks/subnets', VnetParameters.vnetName, VnetParameters.subnetName)
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    createPublicIP: false
    location: location
  }
  dependsOn: [
    deployVnet
  ]
}

module deployVmADCS 'templates/vm.bicep' = {
  name: '${az.deployment().name}-vmADCS'
  params: {
    vmName: ADCSParameters.vmName
    vmIp: ADCSParameters.ipAddress
    snetId: resourceId('Microsoft.Network/virtualNetworks/subnets', VnetParameters.vnetName, VnetParameters.subnetName)
    adminUsername: ADCSParameters.adminUsername
    adminPassword: ADCSParameters.adminPassword
    createPublicIP: true
    asgVpnId: deployVnet.outputs.asgVpnId
    asgRdpId: deployVnet.outputs.asgRdpId
    location: location
  }
  dependsOn: [
    deployVnet
  ]
}

module deployVmNPS 'templates/vm.bicep' = {
  name: '${az.deployment().name}-vmNPS'
  params: {
    vmName: NPSParameters.vmName
    vmIp: NPSParameters.ipAddress
    snetId: resourceId('Microsoft.Network/virtualNetworks/subnets', VnetParameters.vnetName, VnetParameters.subnetName)
    adminUsername: NPSParameters.adminUsername
    adminPassword: NPSParameters.adminPassword
    createPublicIP: false
    location: location
  }
  dependsOn: [
    deployVnet
  ]
}

module deployVmRRAS 'templates/vm.bicep' = {
  name: '${az.deployment().name}-vmRRAS'
  params: {
    vmName: RRASParameters.vmName
    vmIp: RRASParameters.ipAddress
    snetId: resourceId('Microsoft.Network/virtualNetworks/subnets', VnetParameters.vnetName, VnetParameters.subnetName)
    adminUsername: RRASParameters.adminUsername
    adminPassword: RRASParameters.adminPassword
    createPublicIP: true
    asgVpnId: deployVnet.outputs.asgVpnId
    asgRdpId: deployVnet.outputs.asgRdpId
    location: location
  }
  dependsOn: [
    deployVnet
  ]
}

resource vmADDS 'Microsoft.Compute/virtualMachines@2020-12-01' existing = {
  name: ADDSParameters.vmName
}

resource dsc 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: vmADDS
  name: '${ADDSParameters.vmName}-DSC'
  location: location
  dependsOn: [
    deployVmADDS
  ]
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.9'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: '${artifactsLocation}/DSC/CreateADPDC.zip'
        script: 'CreateADPDC.ps1'
        function: 'CreateADPDC'
      }
      configurationArguments: {
        DomainName: ADDSParameters.dnsPrefix
      }
    }
    protectedSettings: {
      configurationArguments: {
        AdminCreds: {
          UserName: ADDSParameters.adminUsername
          Password: ADDSParameters.adminPassword
        }
      }
    }
  }
}
