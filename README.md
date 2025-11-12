# documentation

This repo contains the docs provided by <https://docs.fluent.do>.
Documentation is generated via `mkdocs` and hosted in Vercel.

## Security reporting

The security documentation is all generated via [`scripts/security/run-scans.sh`](scripts/security/run-scans.sh) once a week automatically.
The versions to be scanned (OSS and FluentDo) are configured in [`scripts/security/scan-config.json`](scripts/security/scan-config.json).

Markdown templates are provided for Grype in [`scripts/security/templates/grype-markdown.tmpl`](scripts/security/templates/grype-markdown.tmpl).

[Instructions are provided](./docs/security/triaged/README.md) for how to triage CVEs.
