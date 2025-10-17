# Agent Handbook

## Mission Overview
- **Repository scope:** Bicep automation for Network Services. Contains the infrastructure templates, configuration, and tests executed through the shared pipeline stack (dispatcher -> pipeline-common).
- **Primary pipeline files:** `pipeline/networkservices.pipeline.yml` exposes Azure DevOps parameters; `pipeline/networkservices.settings.yml` links to the dispatcher and forwards configuration.
- **Action groups:** `bicep_actions` deploys the resource group then the network services Bicep. `bicep_tests_resource_group` and `bicep_tests_network_services` execute Pester suites via Azure CLI with `kind: pester`, so the shared templates publish `TestResults/<actionGroup>_<action>.xml` automatically.
- **Dependencies:** The settings template references `wesley-trust/pipeline-dispatcher`, which locks `wesley-trust/pipeline-common`. Review those repos when diagnosing pipeline behaviour.

## Repository Layout
- `pipeline/` – Pipeline definition + settings. Edit these when introducing new parameters, toggles, or action groups.
- `platform/` – Bicep templates (`resourcegroup`, `networkservices`) and parameter files referenced by the pipeline actions.
- `vars/` – Layered YAML variables (`common`, `regions/*`). Loaded by `pipeline-common` based on include flags supplied via configuration.
- `scripts/` – PowerShell helpers invoked from pipeline actions (Pester run/review, example hooks). Executed within the locked pipeline snapshot.
- `tests/` – Pester suites grouped into `smoke`, `regression`, etc. Align folder names with the pipeline action definitions; shared design fixtures under `tests/design/` expose `tags`, `health`, and per-resource property sets consumed by the suites.

## Pipeline Execution Flow
1. `networkservices.pipeline.yml` defines runtime parameters (production enablement, DR toggle, environment skips, action/test switches) and extends the matching settings file.
2. `networkservices.settings.yml` declares the `PipelineDispatcher` repository resource and re-extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. The dispatcher merges defaults with consumer overrides (including the optional `pipelineType` suffix) and forwards the resulting `configuration` into `pipeline-common/templates/main.yml`.
4. `pipeline-common` orchestrates initialise, validation, optional review, and deploy stages, loading variables and executing the action groups defined here. Refer to `pipeline-common/AGENTS.md` and `docs/CONFIGURE.md` for the full contract. When `pipelineType` is set (tests pipeline uses `auto`), Azure DevOps environments receive the same suffix so automated lanes can bypass manual approvals; the tests pipeline also sets `globalDependsOn: validation` to gate every action group on template validation.

## Customisation Points
- Adjust action wiring in `networkservices.pipeline.yml` to add new Bicep modules, split deployments, or change scripts. Respect the schema expected by `pipeline-common` (`type`, `scope`, `templatePath`, etc.).
- Override environment metadata (pools, regions, approvals) through the configuration object in the settings file (`environments`, `skipEnvironments`, additional repositories, key vault options).
- Manage variables by editing YAML files under `vars/` and toggling include flags via dispatcher configuration.
- Introduce review artefacts or notifications by composing additional action groups (e.g., PowerShell review tasks) in the pipeline definition.

## Testing and Validation
- `scripts/pester_run.ps1` installs required modules, authenticates with the federated token passed from Azure CLI, and executes Pester with NUnit output. It expects `-PathRoot`, `-Type`, and `-TestData.Name` so the runner can locate suites like `tests/<type>/<service>`. Ensure new tests live under `tests/` and are referenced by the action group.
- Smoke suites now validate the `health` object emitted by each design file (for example, `provisioningState`) to give a quick readiness signal without broad property asserts. Expand the health payload when additional status checks are needed.
- Review stage relies on pipeline-common’s Bicep what-if output for approval context. `scripts/pester_review.ps1` ships for future opt-in review tasks but is not wired into the current pipeline definitions.
- CI action groups in `networkservices.tests.pipeline.yml` enable `variableOverridesEnabled` and pass overrides such as `dynamicDeploymentVersionEnabled` or `excludeTypeVirtualNetworkPeerings`. The helper template `PipelineCommon/templates/variables/include-overrides.yml` turns those keys into pipeline variables and generates unique deployment versions per run, keeping parallel tests isolated.
- Bicep syntax/what-if validation runs through `pipeline-common` validation/review stages; run `az bicep build` locally for quick feedback before pushing.

## Operational Notes
- Document any behavioural change (new parameters, action groups, dependency updates) in `README.md` or inline comments so future agents understand the contract.
- When dispatcher defaults need adjustment (e.g., service connections, pool names), coordinate updates in the dispatcher repo to maintain compatibility.
- Use the preview tooling in `pipeline-common/tests` to validate changes against Azure DevOps definitions before merging.

## References
- `pipeline-dispatcher/AGENTS.md` – how consumer configuration merges with shared defaults.
- `pipeline-common/AGENTS.md` + `docs/CONFIGURE.md` – canonical stage and configuration documentation.
- `pipeline-examples` – end-to-end samples demonstrating how consumer repos should call the dispatcher.
