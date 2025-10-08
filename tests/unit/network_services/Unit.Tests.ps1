[CmdletBinding()]
Param(
  [string]$DesignRoot = "./tests/design/network_services",
  [string]$Location = $ENV:REGION,
  [string]$RegionCode = $ENV:REGIONCODE,
  [string]$Environment = $ENV:ENVIRONMENT,
  [ValidateSet("Full", "Environment", "Region")][string]$DesignPathSwitch = "Region",
  [string]$ResourceGroupTemplateFile = "./platform/resourcegroup.bicep",
  [string]$ResourceGroupParameterFile = "./platform/resourcegroup.bicepparam",
  [string]$ResourceTemplateFile = "./platform/networkservices.bicep",
  [string]$ResourceParameterFile = "./platform/networkservices.bicepparam",
  [string]$ResourceGroupName = $ENV:RESOURCEGROUP
)

BeforeDiscovery {
  
  $ErrorActionPreference = 'Stop'
  Set-StrictMode -Version Latest

  # Determine Design Path
  switch ($DesignPathSwitch) {
    "Root" {
      $DesignPath = "$DesignRoot"
    }
    "Environment" {
      $DesignPath = "$DesignRoot/environments/$Environment"
    }
    "Region" {
      $DesignPath = "$DesignRoot/environments/$Environment/regions/$RegionCode"
    }
  }

  # Import Design
  if (Test-Path -Path $DesignPath -PathType Container) {
    $DesignFiles = Get-ChildItem -Path $DesignPath -Filter "*.design.json" -File | Sort-Object -Property Name

    if (!$DesignFiles) {
      throw "No design files found in '$DesignPath'."
    }

    # Build Design JSON array from multiple files
    $script:Design = foreach ($File in $DesignFiles) {
      $Content = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json

      if ($Content -is [System.Array]) {
        $Content
      }
      else {
        @($Content)
      }
    }
  }
  else {
    $script:Design = Get-Content -Path $DesignPath -Raw | ConvertFrom-Json
  }

  # Get unique Resource Types
  $script:ResourceTypes = $Design.resourceType | Sort-Object -Unique

  # Resource Types that do not have tags
  $script:ResourceTypeTagExclusion = @(
    'Microsoft.Network/virtualNetworks/virtualNetworkPeerings'
    'Microsoft.Network/virtualNetworks/subnets'
  )
}

BeforeAll {

  function ConvertTo-BooleanValue {
    [CmdletBinding()]
    param (
      [parameter(
        Mandatory = $true,
        ValueFromPipeLineByPropertyName = $true,
        ValueFromPipeline = $true
      )]
      [string]$Value
    )

    process {
      if ($null -eq $Value) {
        return $false
      }

      switch ($Value) {
        { $_ -is [bool] } { return $_ }
        { $_ -is [int] } { return [bool]$_ }
        { $_ -is [string] } {
          $normalized = $_.Trim()
          if ($normalized -match '^(?i:true|1)$') { return $true }
          if ($normalized -match '^(?i:false|0)$') { return $false }
          break
        }
      }

      throw 'Must be a boolean-compatible value (true/false, 1/0).'
    }
  }

  function Invoke-StackDeployment {
    param(
      [string[]]$BaseArgs,
      [bool]$AllowDelete
    )

    $initialAction = if ($AllowDelete) { 'deleteAll' } else { 'detachAll' }
    $initialArgs = $BaseArgs + @('--action-on-unmanage', $initialAction)

    try {
      az @initialArgs
    }
    finally {
      if ($AllowDelete) {
        $resetArgs = $BaseArgs + @('--action-on-unmanage', 'detachAll')
        try {
          az @resetArgs | Out-Null
        }
        catch {
          Write-Warning "Failed to restore action-on-unmanage to detachAll: $($_.Exception.Message)"
        }
      }
    }
  }

  function Get-StackName {
    param(
      [string]$Prefix,
      [string]$Identifier,
      [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Identifier)) {
      throw 'Identifier is required to compute the stack name.'
    }
    $parts = @($Prefix, $Identifier)

    if (-not [string]::IsNullOrWhiteSpace($Name)) {
      $sanitisedName = $Name.Trim()
      if ($sanitisedName -and -not $sanitisedName.Equals($Identifier, [System.StringComparison]::OrdinalIgnoreCase)) {
        $parts += $sanitisedName
      }
    }

    # Build raw name; remove spaces around parts but don't alter valid characters
    $raw = ($parts -join '-').Trim()

    # Allow: letters, digits, underscore, hyphen, dot, parentheses
    $sanitised = ($raw -replace '[^-\w\._\(\)]', '-').Trim('-')
    if (-not $sanitised) { $sanitised = $Prefix }

    if ($sanitised.Length -gt 90) {
      $sanitised = $sanitised.Substring(0, 90).Trim('-')
      if (-not $sanitised) { $sanitised = $Prefix }
    }

    return $sanitised
  }

  $ResourceGroupExists = az group exists --name $ResourceGroupName | ConvertTo-BooleanValue

  if (!$ResourceGroupExists) {
    
    $StackName = Get-StackName -Prefix 'ds-sub' -Identifier $ResourceGroupName

    $stackCommandBase = @(
      'stack', 'sub', 'create',
      '--name', $StackName,
      '--location', $Location,
      '--template-file', $ResourceGroupTemplateFile,
      '--parameters', $ResourceGroupParameterFile,
      '--deny-settings-mode', 'DenyWriteAndDelete',
      '--only-show-errors'
    )

    Invoke-StackDeployment -BaseArgs $stackCommandBase -AllowDelete:$false
  }
  
  # Generate Bicep What-If
  $WhatIf = az deployment group what-if --resource-group $ResourceGroupName --template-file $ResourceTemplateFile --parameters $ResourceParameterFile --only-show-errors --no-pretty-print

  # Create WhatIfObject if WhatIf is not null or empty, and optionally publish artifact
  if ($WhatIf) {
    if ($ENV:PUBLISHTESTARTIFACTS) {
      $WhatIf | Out-File -FilePath "$ENV:BUILD_ARTIFACTSTAGINGDIRECTORY/bicep.whatif.json"
    }
    $WhatIfObject = $WhatIf | ConvertFrom-Json

    $BicepChangesAfter = $WhatIfObject.changes.after
  }
  else {
    throw "What-If operation failed or returned no results."
  }
}

Describe "Resource Design" {
  
  Context "Integrity Check" {
    
    It "should have at least one Resource Type" {

      # Act
      $ActualValue = @($ResourceTypes).Count

      # Assert
      $ActualValue | Should -BeGreaterThan 0
    }
  }
}

Describe "Resource Type '<_>'" -ForEach $ResourceTypes {

  BeforeDiscovery {
    
    $ResourceType = $_

    $Resources = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).resources
    $Tags = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).tags

    if ($null -ne $Tags) {
      $TagsObject = @(
        $Tags.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
    }
    else {
      $TagsObject = @()
    }
  }

  BeforeAll {
    
    $ResourceType = $_

    $Resources = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).resources
    $Tags = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).tags

    if ($null -ne $Tags) {
      $TagsObject = @(
        $Tags.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
    }
    else {
      $TagsObject = @()
    }
    
    $WhatIfResources = $BicepChangesAfter | Where-Object { $_.type -eq $ResourceType }
  }

  Context "Integrity Check" {
    
    It "should have at least one Resource" {

      # Act
      $ActualValue = @($Resources).Count

      # Assert
      $ActualValue | Should -BeGreaterThan 0
    }
    
    It "should have at least one Tag" -Skip:($ResourceTypeTagExclusion -contains $ResourceType) {

      # Act
      $ActualValue = $TagsObject.Count

      # Assert
      $ActualValue | Should -BeGreaterThan 0
    }
  }

  Context "Resource Name '<_.name>'" -ForEach $Resources {

    BeforeDiscovery {
      
      $Resource = $_

      $PropertiesObject = @(
        $Resource.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
    }

    BeforeAll {
      
      $Resource = $_
      
      $PropertiesObject = @(
        $Resource.PSObject.Properties |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Value = $_.Value } }
      )
      
      $WhatIfResource = $WhatIfResources | Where-Object { $_.name -eq $Resource.Name }
    }

    Context "Integrity Check" {
      
      It "should have at least one Property" {

        # Act
        $ActualValue = $PropertiesObject.Count

        # Assert
        $ActualValue | Should -BeGreaterThan 0
      }
    }

    Context "Properties" {
      
      It "should have property '<_.Name>' with value '<_.Value>'" -ForEach $PropertiesObject {
        
        # Arrange
        $Property = $_
        
        # Mapping of flattened design properties to their nested properties in the WhatIf
        $PropertyMapping = @{
          'Microsoft.Network/virtualNetworks'         = @{
            addressPrefixes        = { param($Resource) $Resource.properties.addressSpace.addressPrefixes }
            dnsServers             = { param($Resource) $Resource.properties.dhcpOptions.dnsServers }
            subnetNames            = { param($Resource) $Resource.properties.subnets.name }
            virtualNetworkPeerings = { param($Resource) $Resource.properties.virtualNetworkPeerings.name }
          }
          'Microsoft.Network/networkSecurityGroups'   = @{
            securityRuleNames = { param($Resource) $Resource.properties.securityRules.name }
          }
          'Microsoft.Network/routeTables'             = @{
            routeNames = { param($Resource) $Resource.properties.routes.name }
          }
          'Microsoft.Network/virtualNetworks/subnets' = @{
            addressPrefix          = { param($Resource) $Resource.properties.addressPrefix }
            delegationName         = { param($Resource) $Resource.properties.delegations.name }
            networkSecurityGroupId = { param($Resource) $Resource.properties.networkSecurityGroup.id }
            routeTableId           = { param($Resource) $Resource.properties.routeTable.id }
          }
        }

        # Act
        # If the property mapping exists for the resource type and property name, use it to extract the property path
        if ($PropertyMapping[$ResourceType]?.ContainsKey($Property.Name)) {
          $ActualValue = & $PropertyMapping[$ResourceType][$Property.Name] $WhatIfResource
        }
        else {
          $ActualValue = $WhatIfResource.$($Property.Name)
        }

        # Assert
        $ActualValue | Should -Be $Property.Value
      }
    }

    Context "Tags" {
      
      It "should have tag '<_.Name>' with value '<_.Value>'" -ForEach $TagsObject {
        
        # Arrange
        $Tag = $_

        # Act
        $ActualValue = $WhatIfResource.Tags.$($Tag.Name)

        # Assert
        $ActualValue | Should -BeExactly $Tag.Value
      }
    }
  }
}
