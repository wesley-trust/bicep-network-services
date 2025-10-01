using './resourcegroup.bicep'

param deployResourceGroupString = '#{{ deployResourceGroup }}'

param location = '#{{ region }}'
param resourceGroupName = '#{{ resourceGroup }}'

param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}
