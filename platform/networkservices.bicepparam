using './networkservices.bicep'

// Common
param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}

// Service
param deployNetworkServicesString = '#{{ deployNetworkServices }}'

// Route Table
param deployRouteTableString = '#{{ deployRouteTable }}'

param routeTables = [
  {
    name: 'rt-#{{ snet-001-name }}'
    routes: [
      {
        name: 'SharedServices-PROD-vnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          nextHopIpAddress: '10.4.0.4'
          nextHopType: 'VirtualAppliance'
        }
      }
      {
        name: 'home'
        properties: {
          addressPrefix: '192.168.1.0/24'
          nextHopIpAddress: '10.4.0.4'
          nextHopType: 'VirtualAppliance'
        }
      }
    ]
  }
]

// Network Security Group
param deployNetworkSecurityGroupString = '#{{ deployNetworkSecurityGroup }}'

param networkSecurityGroups = [
  {
    name: 'nsg-#{{ snet-001-name }}'
    securityRules: [
      {
        name: 'allow-SharedServices-PROD-vnet-inbound'
        properties: {
          access: 'Allow'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          direction: 'Inbound'
          priority: 100
          protocol: '*'
          sourceAddressPrefix: '10.0.2.0/24'
          sourcePortRange: '*'
        }
      }
      {
        name: 'allow-home-inbound'
        properties: {
          access: 'Allow'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          direction: 'Inbound'
          priority: 200
          protocol: '*'
          sourceAddressPrefix: '192.168.1.0/24'
          sourcePortRange: '*'
        }
      }
    ]
  }
]

// Virtual Network
param deployVirtualNetworkString = '#{{ deployVirtualNetwork }}'

param virtualNetworkName = '#{{ vnet-001-name }}'

param addressPrefixes = [
  '#{{ vnet-001-addressPrefix }}'
]

param dnsServers = [
  '#{{ vnet-001-dnsPrimaryServer }}'
  '#{{ vnet-001-dnsSecondaryServer }}'
]

param subnets = [
  {
    name: '#{{ snet-001-name }}'
    addressPrefix: '#{{ snet-001-addressPrefix }}'
    delegation: 'Microsoft.App/environments'
  }
]

param peerings = [
  {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    remotePeeringAllowForwardedTraffic: true
    remotePeeringAllowVirtualNetworkAccess: true
    remotePeeringEnabled: true
    remoteVirtualNetworkResourceId: '#{{ lvg-shared-remoteVirtualNetworkResourceId }}'
    useRemoteGateways: false
  }
]
