param vnetName string
param vnetIPRange string
param snetName string
param snetIPRange string
param location string
param asgVpnName string = 'asgVpn'
param asgRdpName string = 'asgRdp'

resource asgVPN 'Microsoft.Network/applicationSecurityGroups@2020-11-01' = {
  name: asgVpnName
  location: location
}

resource asgRDP 'Microsoft.Network/applicationSecurityGroups@2020-11-01' = {
  name: asgRdpName
  location: location
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: 'nsg-${snetName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allowVpnIn'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgVPN.id
            }
          ]
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'allowRDPIn' // This rule is just for testing
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgRDP.id
            }
          ]
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
    ]
  }
}

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
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

output asgVpnId string = asgVPN.id
output asgRdpId string = asgRDP.id
