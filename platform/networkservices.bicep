targetScope = 'resourceGroup'

// Common
@description('Azure region for the virtual network. Defaults to the current resource group location.')
param location string = resourceGroup().location

@description('Optional tags applied to the resources.')
param tags object = {}
var normalizedTags = empty(tags) ? null : tags

// Route Table
@description('Flag to determine whether to deploy the route table. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployRouteTableString string

@description('Convert the deployRouteTableString parameter to a boolean value.')
var deployRouteTable = bool(deployRouteTableString)

@description('Name of the route table to create.')
param routeTableName string

@description('Array of routes to create within the route table, in routeType (object) format.')
param routes array

module routeTable 'br/public:avm/res/network/route-table:0.5.0' = if (deployRouteTable == true) {
  params: {
    name: routeTableName
    routes: routes
    location: location
    tags: normalizedTags
  }
}

// Virtual Network
@description('Flag to determine whether to deploy the virtual network spoke. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployVirtualNetworkString string

@description('Convert the deployVirtualNetworkString parameter to a boolean value.')
var deployVirtualNetwork = bool(deployVirtualNetworkString)

@description('Name of the virtual network spoke to create.')
param virtualNetworkName string

@description('Array representing the address prefixes assigned to the virtual network, e.g. ["10.10.0.0/16"].')
param addressPrefixes array = []

@description('Array of DNS servers to assign to the virtual network. If empty, Azure default DNS servers will be used.')
param dnsServers array = []

@description('Array describing the subnets, in subnetType (object) to create within the virtual network.')
param subnets array = []
var subnetsWithRt = [
  for subnet in subnets: union(subnet, {
    routeTableResourceId: resourceId('Microsoft.Network/routeTables', 'rt-${subnet.name}')
  })
]

@description('Array of virtual network peerings to create. Each peering should be in peeringType (object) format.')
param peerings array = []

@description('Optional flag to enable VM protection on all subnets within the virtual network.')
param enableVmProtection bool?

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = if (deployVirtualNetwork == true && deployRouteTable == true) {
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: addressPrefixes
    dnsServers: dnsServers
    subnets: subnetsWithRt
    peerings: peerings
    tags: normalizedTags
    enableVmProtection: enableVmProtection
  }
  dependsOn: [
    routeTable
  ]
}
