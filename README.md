# bicep-network-services

Infrastructure-as-code for Wesley Trust network services. The repository contains Bicep templates, configuration, and automated tests executed through the shared pipeline stack (`pipeline-dispatcher` -> `pipeline-common`).

## Quick Links
- `AGENTS.md` – AI-focused handbook describing action groups, validation, and dependency repos.
- `pipeline/networkservices.deploy.pipeline.yml` – Azure DevOps pipeline definition with runtime parameters.
- `pipeline/networkservices.tests.pipeline.yml` – CI/scheduled tests pipeline built on the same dispatcher handshake.
- `pipeline/networkservices.settings.yml` – dispatcher handshake that forwards configuration to `pipeline-common`.
- `pipeline/networkservices.publish.pipeline.yml` – semantic-release pipeline that tags main merges and publishes GitHub releases.
- `pipeline-common/docs/CONFIGURE.md` – canonical schema reference for configuration payloads.

## Repository Layout
- `platform/` – Bicep artefacts. `resourcegroup.bicep` prepares prerequisite RGs; `networkservices.bicep` applies the network workload. `.bicepparam` files capture parameter defaults.
- `pipeline/` – Pipeline definition and dispatcher settings. Adjust these files when exposing new toggles or action groups.
- `vars/` – YAML variable layers (`common.yml`, `regions/*.yml`) that `pipeline-common` loads according to include flags.
- `scripts/` – PowerShell helpers executed by the pipeline (Pester runner, review metadata, sample pre/post scripts).
- `tests/` – Pester suites grouped into `regression`, `smoke`, and optional folders for unit/integration coverage. Shared design fixtures live under `tests/design/`, where each resource type now includes `tags`, `health`, and per-resource property sets.

## Pipeline Overview
1. `networkservices.deploy.pipeline.yml` introduces parameters for production enablement, DR invocation, environment skips, and action-group toggles before extending the settings template.
2. `networkservices.settings.yml` declares repository resource `PipelineDispatcher` and extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. The dispatcher merges defaults, declares `PipelineCommon`, and calls `templates/main.yml@PipelineCommon` with the composed `configuration` object.
4. Action groups:
   - `bicep_actions` – deploys the resource group followed by the network services Bicep module, with optional cleanup and delete-on-unmanage toggles.
   - `bicep_tests_resource_group` and `bicep_tests_network_services` – execute Pester suites through Azure CLI. Each action passes a scoped fixture via `-TestData` so the runner can resolve paths like `tests/<type>/<service>`, and both groups rely on `kind: pester`, which triggers `pipeline-common` to publish NUnit results to `TestResults/<actionGroup>_<action>.xml`.

The dedicated tests pipeline (`networkservices.tests.pipeline.yml`) passes `pipelineType: auto` and sets `globalDependsOn: validation`, ensuring CI and scheduled jobs wait for template validation. CI-facing action groups (`bicep_tests_*_ci`) enable `variableOverridesEnabled` with `dynamicDeploymentVersionEnabled: true`, allowing `templates/variables/include-overrides.yml` to append a unique suffix to `deploymentVersion` per run so parallel test executions stay isolated.

## Test Fixtures and Health Checks
- Design files under `tests/design/network_services/**` expose a top-level `health` object (typically `provisioningState` or service-specific readiness hints) alongside resource properties. Smoke tests assert these health keys directly against live resources to provide a fast readiness signal without expanding property skip matrices.
- Regression and integration suites consume the same design data, filtering properties as required while still validating tags and nested collections.
- Resource-group fixtures live under `tests/design/resource_group/**` and are passed into the runner the same way.

The release pipeline (`networkservices.publish.pipeline.yml`) also runs with `pipelineType: auto`, scoped to the dev environment only. It executes `scripts/release_semver.ps1` after every successful `main` build to derive the semantic version from the squash-merge commit message, create/push the tag, and surface release metadata. A PowerShell action with `kind: release` then wraps `GitHubRelease@1` to publish the GitHub Release entry using the variables set by the script.

## Local Development
- Install PowerShell 7, Azure CLI (with Bicep CLI support), and the Az PowerShell module to mirror pipeline execution.
- Exercise tests locally using `pwsh -File scripts/pester_run.ps1 -PathRoot tests -Type smoke -TestData @{ Name = 'network_services' } -ResultsFile ./TestResults/local.smoke.xml`, authenticating with Azure beforehand. Swap `smoke` with `regression` (and adjust `Name`) to target other suites.
- Run `az bicep build platform/networkservices.bicep` for syntax validation while authoring templates.

## Configuration Tips
- Tune environment metadata (pools, regions, approvals) by editing the configuration payload in `networkservices.settings.yml`.
- Manage variable layers under `vars/` and control their inclusion with `configuration.variables.include*` flags.
- Additional repositories, key vault integration, and advanced validation options follow the schema defined in `pipeline-common/docs/CONFIGURE.md`.

## Releasing Changes
- Document new parameters or action groups in both `README.md` and `AGENTS.md` to keep operators informed.
- Coordinate dispatcher default updates with the `pipeline-dispatcher` team to avoid schema drift.
- Cover breaking infrastructure changes with regression tests and clear migration notes in pull requests.

## Support
Use the platform DevOps channel or this repository’s issue tracker for support. Include pipeline run details, branch, and relevant configuration overrides when reporting problems.
