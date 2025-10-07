[CmdletBinding()]
Param(
  [string]$DesignRoot = "./tests/design/resource_group",
  [string]$Location = $ENV:REGION,
  [string]$RegionCode = $ENV:REGIONCODE,
  [string]$Environment = $ENV:ENVIRONMENT,
  [ValidateSet("Full", "Environment")][string]$Common,
  [string]$ResourceGroupTemplateFile = "./platform/resourcegroup.bicep",
  [string]$ResourceGroupParameterFile = "./platform/resourcegroup.bicepparam"
)

BeforeDiscovery {
  $ErrorActionPreference = 'Stop'
  Set-StrictMode -Version Latest

  # Determine Design Path
  if ($Common -eq "Full") {
    $DesignPath = "$DesignRoot/common.design.json"
  }
  elseif ($Common -eq "Environment") {
    $DesignPath = "$DesignRoot/environments/$Environment/common.design.json"
  }
  else {
    $DesignPath = "$DesignRoot/environments/$Environment/regions/$RegionCode.design.json"
  }

  # Import Design
  $script:Design = Get-Content -Path $DesignPath -Raw | ConvertFrom-Json

  # Get unique Resource Types
  $script:ResourceTypes = $Design.resourceType | Sort-Object -Unique
}

BeforeAll {
  # Generate Bicep What-If
  $WhatIf = az deployment sub what-if --location $Location --template-file $ResourceGroupTemplateFile --parameters $ResourceGroupParameterFile --only-show-errors --no-pretty-print

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
      @($ResourceTypes).Count | Should -BeGreaterThan 0
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
      @($Resources).Count | Should -BeGreaterThan 0
    }
    It "should have at least one Tag" {
      $TagsObject.Count | Should -BeGreaterThan 0
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
        $PropertiesObject.Count | Should -BeGreaterThan 0
      }
    }

    Context "Properties" {
      It "should have property '<_.Name>' with value '<_.Value>'" -ForEach $PropertiesObject {
        $Property = $_
        
        $ActualValue = $WhatIfResource.$($Property.Name)

        $ActualValue | Should -Be $Property.Value
      }
    }

    Context "Tags" {
      It "should have tag '<_.Name>' with value '<_.Value>'" -ForEach $TagsObject {
        $Tag = $_
        
        $WhatIfResource.Tags.$($Tag.Name) | Should -BeExactly $Tag.Value
      }
    }
  }
}