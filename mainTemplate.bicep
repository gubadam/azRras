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

param location string = resourceGroup().location

module vnet 'templates/vnet.bicep' = {
  name: '${az.deployment().name}-vnet'
  params: {
    vnetName: VnetParameters.vnetName
    vnetIPRange: VnetParameters.vnetIPRange
    snetName: VnetParameters.subnetName
    snetIPRange: VnetParameters.subnetIPRange
    location: location
  }
}

module vmADDS 'templates/vm.bicep' = {
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
    vnet
  ]
}

module vmADCS 'templates/vm.bicep' = {
  name: '${az.deployment().name}-vmADCS'
  params: {
    vmName: ADCSParameters.vmName
    vmIp: ADCSParameters.ipAddress
    snetId: resourceId('Microsoft.Network/virtualNetworks/subnets', VnetParameters.vnetName, VnetParameters.subnetName)
    adminUsername: ADCSParameters.adminUsername
    adminPassword: ADCSParameters.adminPassword
    createPublicIP: true
    asgVpnId: vnet.outputs.asgVpnId
    asgRdpId: vnet.outputs.asgRdpId
    location: location
  }
  dependsOn: [
    vnet
  ]
}

module vmNPS 'templates/vm.bicep' = {
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
    vnet
  ]
}

module vmRRAS 'templates/vm.bicep' = {
  name: '${az.deployment().name}-vmRRAS'
  params: {
    vmName: RRASParameters.vmName
    vmIp: RRASParameters.ipAddress
    snetId: resourceId('Microsoft.Network/virtualNetworks/subnets', VnetParameters.vnetName, VnetParameters.subnetName)
    adminUsername: RRASParameters.adminUsername
    adminPassword: RRASParameters.adminPassword
    createPublicIP: true
    asgVpnId: vnet.outputs.asgVpnId
    asgRdpId: vnet.outputs.asgRdpId
    location: location
  }
  dependsOn: [
    vnet
  ]
}
