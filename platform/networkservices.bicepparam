using './networkservices.bicep'

param deployVirtualNetworkString = '#{{ deployVirtualNetwork }}'

param virtualNetworkName = '#{{ vnet-001-name }}'
param addressPrefixes = [
  '#{{ vnet-001-addressPrefix }}'
]
param subnets = [
  {
    name: '#{{ snet-001-name }}'
    addressPrefix: '#{{ snet-001-addressPrefix }}'
  }
]
param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}
