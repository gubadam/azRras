param vmName string
param vmIp string
param snetId string
param adminUsername string

@secure()
param adminPassword string

resource vmName_netInt01 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${vmName}-netInt01'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1${vmName}'
        properties: {
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: snetId
          }
          privateIPAddress: vmIp
        }
      }
    ]
  }
  dependsOn: []
}

resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: vmName
  location: resourceGroup().location
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
