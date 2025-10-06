[CmdletBinding()]
Param(
  [string]$DesignPath = "./tests/design/resource_group/resourcegroup.tests.json"
)

BeforeDiscovery {
  $ErrorActionPreference = 'Stop'
  Set-StrictMode -Version Latest

  # Import Design
  $script:Design = Get-Content -Path $DesignPath -Raw | ConvertFrom-Json

  # Get unique Resource Types
  $script:ResourceTypes = $Design.resourceType | Sort-Object -Unique
}

Describe "Resource Design" {
  Context "Integrity Check" {
    It "should have at least one Resource Type" {
      $ResourceTypes.Count | Should -BeGreaterThan 0
    }
  }
}

Describe "Resource Type '<_>'" -ForEach $ResourceTypes {
  $ResourceType = $_

  BeforeDiscovery {
    
    $script:Resources = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).resources
    $Tags = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).tags

    $script:TagsObject = @(
      $Tags.PSObject.Properties |
      ForEach-Object { [pscustomobject]@{ Name = $_.Name; Value = $_.Value } }
    )
  }

  Context "Integrity Check" {
    It "should have at least one Resource" {
      $Resources.Count | Should -BeGreaterThan 0
    }
  }

  Context "Resource Name '<_.name>'" -ForEach $Resources {
    $Resource = $_

    BeforeDiscovery {
      $script:Properties = $Resource.PSObject.Properties.Name
    }

    Context "Integrity Check" {
      It "should have at least one Property" {
        $Properties.Count | Should -BeGreaterThan 0
      }
      It "should have at least one Tag" {
        $TagsObject.Count | Should -BeGreaterThan 0
      }
    }

    Context "Properties" {
      It "should have property '<_>'" -ForEach $Properties {
        $Property = $_
        $Property | Should -Not -BeNullOrEmpty
      }
    }

    Context "Tags" {
      It "should have tag '<_.Name>' with value '<_.Value>'" -ForEach $TagsObject {
        $Tag = $_
        $Tag.Value | Should -Not -BeNullOrEmpty
      }
    }
  }
}

AfterAll {
  $script:Properties = $null
  $script:Resources = $null
  $script:Design = $null
  $script:ResourceTypes = $null
}