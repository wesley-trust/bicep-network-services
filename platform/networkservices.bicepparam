using './networkservices.bicep'

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

param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}
