# CodeAftermath Monorepo

This repository is organized as a monorepo for CI tooling services.

## Packages

- `lighthouse/`: Lighthouse CI server stack (Terraform, Docker, runbooks, workflows)
- `sonarqube/`: SonarQube stack (structure scaffolded for upcoming setup)

## Lighthouse Entry Points

- Project docs: [lighthouse/README.md](lighthouse/README.md)
- Terraform: [lighthouse/terraform](lighthouse/terraform)
- Docker resources: [lighthouse/docker](lighthouse/docker)
- Ops runbooks: [lighthouse/docs](lighthouse/docs)
- Workflows: [.github/workflows/lighthouse-deploy.yml](.github/workflows/lighthouse-deploy.yml), [.github/workflows/lighthouse-terraform-plan.yml](.github/workflows/lighthouse-terraform-plan.yml)
