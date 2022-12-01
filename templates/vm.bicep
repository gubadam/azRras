param vmName string
param vmIp string
param snetId string
param adminUsername string
param location string

param createPublicIP bool
param asgVpnId string = ''
param asgRdpId string = ''

@secure()
param adminPassword string

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = if (createPublicIP) {
  name: '${vmName}-pip01'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

var publicIpProps = {
  publicIPAddress: {
    id: publicIPAddress.id
  }
  applicationSecurityGroups: createPublicIP ? [{id: asgRdpId}, {id: asgVpnId}] : []
}

var privateIpProps = {
  privateIPAllocationMethod: 'Static'
  subnet: {
    id: snetId
  }
  privateIPAddress: vmIp
}

resource vmName_netInt01 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${vmName}-netInt01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1${vmName}'
        properties: createPublicIP ? union( publicIpProps, privateIpProps) : privateIpProps
      }
    ]
  }
  dependsOn: []
}

resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2016-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmName_netInt01.id
        }
      ]
    }
    diagnosticsProfile: {
    }
  }
}
