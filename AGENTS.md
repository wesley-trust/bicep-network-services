# Agent Handbook

## Mission Overview
- **Repository scope:** Bicep automation for Network Services. Contains the infrastructure templates, configuration, and tests executed through the shared pipeline stack (dispatcher -> pipeline-common).
- **Primary pipeline files:** `pipeline/networkservices.pipeline.yml` exposes Azure DevOps parameters; `pipeline/networkservices.settings.yml` links to the dispatcher and forwards configuration.
- **Action groups:** `bicep_actions` deploys the resource group then the network services Bicep; `bicep_tests` runs Pester suites through Azure CLI to validate deployments.
- **Dependencies:** The settings template references `wesley-trust/pipeline-dispatcher`, which locks `wesley-trust/pipeline-common`. Review those repos when diagnosing pipeline behaviour.

## Repository Layout
- `pipeline/` – Pipeline definition + settings. Edit these when introducing new parameters, toggles, or action groups.
- `platform/` – Bicep templates (`resourcegroup`, `networkservices`) and parameter files referenced by the pipeline actions.
- `vars/` – Layered YAML variables (`common`, `regions/*`). Loaded by `pipeline-common` based on include flags supplied via configuration.
- `scripts/` – PowerShell helpers invoked from pipeline actions (Pester run/review, example hooks). Executed within the locked pipeline snapshot.
- `tests/` – Pester suites grouped into `smoke`, `regression`, etc. Align folder names with the pipeline action definitions.

## Pipeline Execution Flow
1. `networkservices.pipeline.yml` defines runtime parameters (production enablement, DR toggle, environment skips, action/test switches) and extends the matching settings file.
2. `networkservices.settings.yml` declares the `PipelineDispatcher` repository resource and re-extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. The dispatcher merges defaults with consumer overrides and forwards the resulting `configuration` into `pipeline-common/templates/main.yml`.
4. `pipeline-common` orchestrates initialise, validation, optional review, and deploy stages, loading variables and executing the action groups defined here. Refer to `pipeline-common/AGENTS.md` and `docs/CONFIGURE.md` for the full contract.

## Customisation Points
- Adjust action wiring in `networkservices.pipeline.yml` to add new Bicep modules, split deployments, or change scripts. Respect the schema expected by `pipeline-common` (`type`, `scope`, `templatePath`, etc.).
- Override environment metadata (pools, regions, approvals) through the configuration object in the settings file (`environments`, `skipEnvironments`, additional repositories, key vault options).
- Manage variables by editing YAML files under `vars/` and toggling include flags via dispatcher configuration.
- Introduce review artefacts or notifications by composing additional action groups (e.g., PowerShell review tasks) in the pipeline definition.

## Testing and Validation
- `scripts/pester_run.ps1` installs required modules, authenticates with the federated token passed from Azure CLI, and executes Pester with NUnit output. Ensure new tests live under `tests/` and are referenced by the action group.
- Review stage uses `scripts/pester_review.ps1` to surface metadata without running tests, keeping review lightweight.
- Bicep syntax/what-if validation runs through `pipeline-common` validation/review stages; run `az bicep build` locally for quick feedback before pushing.

## Operational Notes
- Document any behavioural change (new parameters, action groups, dependency updates) in `README.md` or inline comments so future agents understand the contract.
- When dispatcher defaults need adjustment (e.g., service connections, pool names), coordinate updates in the dispatcher repo to maintain compatibility.
- Use the preview tooling in `pipeline-common/tests` to validate changes against Azure DevOps definitions before merging.

## References
- `pipeline-dispatcher/AGENTS.md` – how consumer configuration merges with shared defaults.
- `pipeline-common/AGENTS.md` + `docs/CONFIGURE.md` – canonical stage and configuration documentation.
- `pipeline-examples` – end-to-end samples demonstrating how consumer repos should call the dispatcher.
