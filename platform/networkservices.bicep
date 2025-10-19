targetScope = 'resourceGroup'

// Common
@description('Azure region for the virtual network. Defaults to the current resource group location.')
param location string = resourceGroup().location

@description('Optional tags applied to the resources.')
param tags object = {}
var normalizedTags = empty(tags) ? null : tags

// Service
@description('Flag to determine whether to deploy the service. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployServiceString string
var deployService = bool(deployServiceString)

// Route Table
@description('Flag to determine whether to deploy the route table. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployRouteTableString string
var deployRouteTable = bool(deployRouteTableString)

@description('Array of route tables to create.')
param routeTables array

module routeTable 'br/public:avm/res/network/route-table:0.5.0' = [
  for (routeTable, index) in (routeTables ?? []): if (deployService && deployRouteTable) {
    params: {
      name: routeTable.name
      location: location
      routes: routeTable.routes
      tags: normalizedTags
    }
  }
]

// Network Security Group
@description('Flag to determine whether to deploy the network security group. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployNetworkSecurityGroupString string
var deployNetworkSecurityGroup = bool(deployNetworkSecurityGroupString)

@description('Array of network security groups to create.')
param networkSecurityGroups array

module networkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.1' = [
  for (networkSecurityGroup, index) in (networkSecurityGroups ?? []): if (deployService && deployNetworkSecurityGroup) {
    params: {
      name: networkSecurityGroup.name
      location: location
      securityRules: networkSecurityGroup.securityRules
      tags: normalizedTags
    }
  }
]

// Virtual Network
@description('Flag to determine whether to deploy the virtual network spoke. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployVirtualNetworkString string
var deployVirtualNetwork = bool(deployVirtualNetworkString)

@description('Name of the virtual network spoke to create.')
param virtualNetworkName string

@description('Array representing the address prefixes assigned to the virtual network, e.g. ["10.10.0.0/16"].')
param addressPrefixes array = []

@description('Array of DNS servers to assign to the virtual network. If empty, Azure default DNS servers will be used.')
param dnsServers array = []

@description('Array describing the subnets, in subnetType (object) to create within the virtual network.')
param subnets array = []
var subnetsWithRtAndNsg = [
  for subnet in subnets: union(
    subnet,
    deployRouteTable
      ? {
          routeTableResourceId: resourceId('Microsoft.Network/routeTables', 'rt-${subnet.name}')
        }
      : {},
    deployNetworkSecurityGroup
      ? {
          networkSecurityGroupResourceId: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${subnet.name}')
        }
      : {}
  )
]

@description('Flag to disable virtual network peerings during test executions. Accepted values: "true", "false".')
param excludePropertyVirtualNetworkPeeringsString string = 'false'
var excludePropertyVirtualNetworkPeerings = bool(excludePropertyVirtualNetworkPeeringsString)

@description('Array of virtual network peerings to create. Each peering should be in peeringType (object) format.')
param peerings array = []

@description('Optional flag to enable VM protection on all subnets within the virtual network.')
param enableVmProtection bool?

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = if (deployService && deployVirtualNetwork) {
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: addressPrefixes
    dnsServers: dnsServers
    subnets: subnetsWithRtAndNsg
    peerings: excludePropertyVirtualNetworkPeerings ? [] : peerings
    tags: normalizedTags
    enableVmProtection: enableVmProtection
  }
  dependsOn: [
    routeTable
    networkSecurityGroup
  ]
}
