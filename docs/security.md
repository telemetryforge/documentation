# Security information

FluentDo provides an agent with the following security and compliance considerations:

- 24-month LTS support
- Weekly releases for CVEs and critical bugs
- Weekly rebuild against dependency updates
- Backports of critical fixes from OSS or source updates will be done as required
- Daily security scans on core and dependencies
- Fully triaged CVE information via VEX endpoint and webpage
- Fully FIPS compliant (OpenSSL in FIPS mode)
- Full integration and regression testing in place
- Hardened container images and best practice helm charts

## Build and binary security

- SBOM with pinned dependency versions and checksums.
- Official builds are all signed via Sigstore and GPG keys.
- Compiled with ASLR, stack protector, PIE and other secure defaults.
- Memory safety monitored via Valgrind/AddressSanitizer in CI and testing.
- Disable all remote interfaces by default (HTTP/gRPC APIs).
- All remote interfaces require explicit opt-in and authentication by default.

## CVEs

We triage and resolve all CVEs reported against the FluentDo agent (and to some degree OSS too), please see [this page](./security/cves.md).

We also provide a VEX endpoint to integrate with existing tooling to automatically provide this information to security tooling deployed in your infrastructure.
