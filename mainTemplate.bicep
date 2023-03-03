param VnetParameters object
param ADDSParameters object
param ADCSParameters object
param NPSParameters object
param RRASParameters object

param TESTParameters object = {
  vmName: 'vmTest'
  ipAddress: '10.0.0.8'
  adminUsername: 'adminUsername'
  adminPassword: 'adminPassword123'
}

param artifactsLocation string

param location string = resourceGroup().location

// Deploy infra resources
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

module deployVmTEST 'templates/vm.bicep' = {
  name: '${az.deployment().name}-vmTEST'
  params: {
    vmName: TESTParameters.vmName
    vmIp: TESTParameters.ipAddress
    snetId: resourceId('Microsoft.Network/virtualNetworks/subnets', VnetParameters.vnetName, VnetParameters.subnetName)
    adminUsername: TESTParameters.adminUsername
    adminPassword: TESTParameters.adminPassword
    createPublicIP: true
    asgVpnId: deployVnet.outputs.asgVpnId
    asgRdpId: deployVnet.outputs.asgRdpId
    location: location
  }
  dependsOn: [
    deployVnet
  ]
}

// Install DSC dependencies

module DSC_installDependencies_onVmADDS 'templates/dsc-installDependencies.bicep' = {
  name: '${az.deployment().name}-vmADDS-DSC_installDependencies'
  params: {
    vmName: ADDSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    moduleName: [
      'xActiveDirectory', 'xNetworking'
    ]
  }
  dependsOn: [
    deployVmADDS
  ]
}

module DSC_installDependencies_onVmADCS 'templates/dsc-installDependencies.bicep' = {
  name: '${az.deployment().name}-vmADCS-DSC_installDependencies'
  params: {
    vmName: ADCSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    moduleName: [
      // 'ActiveDirectoryCSDsc', 'ComputerManagementDsc'
      'xAdcsDeployment','ComputerManagementDsc','ADCSTemplate'
    ]
  }
  dependsOn: [
    deployVmADCS
  ]
}

module DSC_installDependencies_onVmRRAS 'templates/dsc-installDependencies.bicep' = {
  name: '${az.deployment().name}-vmRRAS-DSC_installDependencies'
  params: {
    vmName: RRASParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    moduleName: [
      'ComputerManagementDsc'
    ]
  }
  dependsOn: [
    deployVmRRAS
  ]
}

module DSC_installDependencies_onVmNPS 'templates/dsc-installDependencies.bicep' = {
  name: '${az.deployment().name}-vmNPS-DSC_installDependencies'
  params: {
    vmName: NPSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    moduleName: [
      'ComputerManagementDsc'
    ]
  }
  dependsOn: [
    deployVmNPS
  ]
}

module DSC_installDependencies_onVmTEST 'templates/dsc-installDependencies.bicep' = {
  name: '${az.deployment().name}-vmTEST-DSC_installDependencies'
  params: {
    vmName: TESTParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    moduleName: [
      'ComputerManagementDsc'
    ]
  }
  dependsOn: [
    deployVmTEST
  ]
}

// Configure Active Directory Domain Services Domain Controller

module DSC_setupADDS_onVmADDS 'templates/dsc-setupADDS.bicep' = {
  name: '${az.deployment().name}-vmADDS-DSC_setupADDS'
  params: {
    vmName: ADDSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
  }
  dependsOn: [
    DSC_installDependencies_onVmADDS
  ]
}

module deployVnetWithCustomDNS 'templates/vnet-withCustomDns.bicep' = {
  name: '${az.deployment().name}-vnetWithCustomDNS'
  params: {
    vnetName: VnetParameters.vnetName
    vnetIPRange: VnetParameters.vnetIPRange
    snetName: VnetParameters.subnetName
    snetIPRange: VnetParameters.subnetIPRange
    location: location
    dnsServer: ADDSParameters.ipAddress
  }
  dependsOn: [
    DSC_setupADDS_onVmADDS
  ]
}

// Join the domain

module DSC_adJoin_onVmADCS 'templates/dsc-domainJoin.bicep' = {
  name: '${az.deployment().name}-vmADCS-DSC_domainJoin'
  params: {
    vmName: ADCSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
  }
  dependsOn: [
    deployVnetWithCustomDNS, DSC_installDependencies_onVmADCS
  ]
}

module DSC_adJoin_onVmRRAS 'templates/dsc-domainJoin.bicep' = {
  name: '${az.deployment().name}-vmRRAS-DSC_domainJoin'
  params: {
    vmName: RRASParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
  }
  dependsOn: [
    deployVnetWithCustomDNS, DSC_installDependencies_onVmRRAS
  ]
}

module DSC_adJoin_onVmNPS 'templates/dsc-domainJoin.bicep' = {
  name: '${az.deployment().name}-vmNPS-DSC_domainJoin'
  params: {
    vmName: NPSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
  }
  dependsOn: [
    deployVnetWithCustomDNS, DSC_installDependencies_onVmNPS
  ]
}

module DSC_adJoin_onVmTEST 'templates/dsc-domainJoin.bicep' = {
  name: '${az.deployment().name}-vmTEST-DSC_domainJoin'
  params: {
    vmName: TESTParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
  }
  dependsOn: [
    deployVnetWithCustomDNS, DSC_installDependencies_onVmTEST
  ]
}

// Configure Ad Groups membership

module DSC_setupAdGroups_onVmADDS 'templates/dsc-setupAdGroups.bicep' = {
  name: '${az.deployment().name}-vmADDS-DSC_setupAdGroups'
  params: {
    vmName: ADDSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
    npsVmHostname: NPSParameters.vmName
    rrasVmHostname: RRASParameters.vmName
  }
  dependsOn: [
    DSC_adJoin_onVmRRAS, DSC_adJoin_onVmNPS, DSC_adJoin_onVmTEST
  ]
}


// Configure Active Directory Certificate Services Root Certificate Authority

module DSC_setupADCS_onVmADCS 'templates/dsc-setupADCS.bicep' = {
  name: '${az.deployment().name}-vmADCS-DSC_setupADCS'
  params: {
    vmName: ADCSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
    crlFqdn: ADCSParameters.crlFqdn
  }
  dependsOn: [
    DSC_adJoin_onVmADCS
  ]
}

// Install Routing and Remote Access Services

module DSC_setupRRAS_onVmRRAS 'templates/dsc-setupRRAS.bicep' = {
  name: '${az.deployment().name}-vmRRAS-DSC_setupRRAS'
  params: {
    vmName: RRASParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
  }
  dependsOn: [
    DSC_adJoin_onVmRRAS, DSC_setupAdGroups_onVmADDS
  ]
}

// Configure certificate templates

module DSC_setupCertTemplates_onVmADCS 'templates/dsc-setupCertTemplates.bicep' = {
  name: '${az.deployment().name}-vmADCS-DSC_setupCertTemplates'
  params: {
    vmName: ADCSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
  }
  dependsOn: [
    DSC_setupADCS_onVmADCS, DSC_setupAdGroups_onVmADDS
  ]
}

// Configure Network Policy Server

module DSC_setupNPS_onVmNPS 'templates/dsc-setupNPS.bicep' = {
  name: '${az.deployment().name}-vmNPS-DSC_setupNPS'
  params: {
    vmName: NPSParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    rrasVmIp: RRASParameters.ipAddress
    adcsVmHostname: ADCSParameters.vmName
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
  }
  dependsOn: [
    DSC_adJoin_onVmNPS, DSC_setupCertTemplates_onVmADCS
  ]
}

// Configure RRAS
module DSC_configRRAS_onVmRRAS 'templates/dsc-configRRAS.bicep' = {
  name: '${az.deployment().name}-vmRRAS-DSC_configRRAS'
  params: {
    vmName: RRASParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    dnsPrefix: ADDSParameters.dnsPrefix
    adminUsername: ADDSParameters.adminUsername
    adminPassword: ADDSParameters.adminPassword
    vpnFqdn: RRASParameters.vpnFqdn
    adcsHostname: ADCSParameters.vmName
    npsVmIp: NPSParameters.ipAddress
  }
  dependsOn: [
    DSC_setupRRAS_onVmRRAS, DSC_setupCertTemplates_onVmADCS, DSC_setupNPS_onVmNPS
  ]
}



module DSC_configVpnClient_onVmTEST 'templates/dsc-configVpnClient.bicep' = {
  name: '${az.deployment().name}-vmTEST-DSC_configVpnClient'
  params: {
    vmName: TESTParameters.vmName
    artifactsLocation: artifactsLocation
    location: location
    vpnFqdn: RRASParameters.vpnFqdn
    adcsHostname:ADCSParameters.vmName
    adminUsername: TESTParameters.adminUsername
    adminPassword: TESTParameters.adminPassword
    dnsPrefix: ADDSParameters.dnsPrefix
    rrasVmName: RRASParameters.vmName
    domainName: ADDSParameters.dnsPrefix
  }
  dependsOn: [
    DSC_configRRAS_onVmRRAS, DSC_adJoin_onVmTEST, DSC_setupNPS_onVmNPS
  ]
}
