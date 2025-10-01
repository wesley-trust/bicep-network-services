using './networkservices.bicep'

// Common
param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}

// Route Table
param deployRouteTableString = '#{{ deployRouteTable }}'

param routeTableName = 'rt-#{{ snet-001-name }}'

param routes = [
  {
    name: 'SharedServices-PROD-vnet'
    properties: {
      addressPrefix: '10.0.2.0/24'
      nextHopIpAddress: '10.4.0.4'
      nextHopType: 'VirtualAppliance'
    }
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
