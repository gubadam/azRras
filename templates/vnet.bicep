param vnetName string
param vnetIPRange string
param snetName string
param snetIPRange string
param location string

resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnetName
  location: location
  tags: {
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetIPRange
      ]
    }
    subnets: [
      {
        name: snetName
        properties: {
          addressPrefix: snetIPRange
        }
      }
    ]
  }
  dependsOn: []
}
