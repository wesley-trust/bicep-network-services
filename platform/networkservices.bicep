targetScope = 'resourceGroup'

@description('Flag to determine whether to deploy the virtual network spoke. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployVirtualNetworkString string

@description('Convert the deployVirtualNetworkString parameter to a boolean value.')
var deployVirtualNetwork = bool(deployVirtualNetworkString)

@description('Name of the virtual network spoke to create.')
param virtualNetworkName string

@description('Azure region for the virtual network. Defaults to the current resource group location.')
param location string = resourceGroup().location

@description('Array representing the address prefixes assigned to the virtual network, e.g. ["10.10.0.0/16"].')
param addressPrefixes array = []

@description('Array of DNS servers to assign to the virtual network. If empty, Azure default DNS servers will be used.')
param dnsServers array = []

@description('Array describing the subnets, in subnetType (object) to create within the virtual network.')
param subnets array = []

@description('Array of virtual network peerings to create. Each peering should be in peeringType (object) format.')
param peerings array = []

@description('Optional tags applied to the virtual network.')
param tags object = {}

@description('Optional flag to enable VM protection on all subnets within the virtual network.')
param enableVmProtection bool?

var normalizedTags = empty(tags) ? null : tags

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.0' = if (deployVirtualNetwork == true) {
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: addressPrefixes
    dnsServers: dnsServers
    subnets: subnets
    peerings: peerings
    tags: normalizedTags
    enableVmProtection: enableVmProtection
  }
}
