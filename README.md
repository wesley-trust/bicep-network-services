# bicep-network-services

Infrastructure-as-code for Wesley Trust network services. The repository contains Bicep templates, configuration, and automated tests executed through the shared pipeline stack (`pipeline-dispatcher` -> `pipeline-common`).

## Quick Links
- `AGENTS.md` – AI-focused handbook describing action groups, validation, and dependency repos.
- `pipeline/networkservices.pipeline.yml` – Azure DevOps pipeline definition with runtime parameters.
- `pipeline/networkservices.settings.yml` – dispatcher handshake that forwards configuration to `pipeline-common`.
- `pipeline-common/docs/CONFIGURE.md` – canonical schema reference for configuration payloads.

## Repository Layout
- `platform/` – Bicep artefacts. `resourcegroup.bicep` prepares prerequisite RGs; `networkservices.bicep` applies the network workload. `.bicepparam` files capture parameter defaults.
- `pipeline/` – Pipeline definition and dispatcher settings. Adjust these files when exposing new toggles or action groups.
- `vars/` – YAML variable layers (`common.yml`, `regions/*.yml`) that `pipeline-common` loads according to include flags.
- `scripts/` – PowerShell helpers executed by the pipeline (Pester runner, review metadata, sample pre/post scripts).
- `tests/` – Pester suites grouped into `regression`, `smoke`, and optional folders for unit/integration coverage.

## Pipeline Overview
1. `networkservices.pipeline.yml` introduces parameters for production enablement, DR invocation, environment skips, and action-group toggles before extending the settings template.
2. `networkservices.settings.yml` declares repository resource `PipelineDispatcher` and extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. The dispatcher merges defaults, declares `PipelineCommon`, and calls `templates/main.yml@PipelineCommon` with the composed `configuration` object.
4. Action groups:
   - `bicep_actions` – deploys the resource group followed by the network services Bicep module, with optional cleanup and delete-on-unmanage toggles.
   - `bicep_tests` – executes the Pester suites through Azure CLI, optionally depending on the deployment action group.

## Local Development
- Install PowerShell 7, Azure CLI (with Bicep CLI support), and the Az PowerShell module to mirror pipeline execution.
- Exercise tests locally using `pwsh -File scripts/pester_run.ps1 -TestsPath tests/smoke -ResultsFile ./TestResults/local.smoke.xml`, authenticating with Azure beforehand.
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
