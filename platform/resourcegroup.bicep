targetScope = 'subscription'

param location string
param resourceGroupName string

module resourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
  params: {
    name: resourceGroupName
    location: location
  }
}
