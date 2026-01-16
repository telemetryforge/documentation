# Security information

We provide an agent with the following security and compliance considerations:

- 24-month LTS support
- Weekly releases for CVEs and critical bugs
- Weekly rebuild against dependency updates
- Backports of critical fixes from OSS or source updates will be done as required
- Daily security scans on core and dependencies
- Fully triaged CVE information via VEX endpoint and webpage
- Fully FIPS compliant (OpenSSL in FIPS mode)
- Full integration and regression testing in place
- Hardened container images and best practice helm charts

## Cosign

All images are signed with Cosign using both the keyless approach with Fulcio and a dedicated Cosign private key (from 25.10.3) integrated into Github Actions directly: <https://github.com/telemetryforge/agent/blob/main/.github/workflows/call-build-containers.yaml>

The public key is available here: <https://raw.githubusercontent.com/telemetryforge/agent/refs/heads/main/cosign.pub>

```text
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE9ksLCy9rhu8BXj7fSYRczjaI+G2K
C7z4JI247+HFGdcJSNh9mSV3ZnlvH44fgqISireDyi8d0WVMf9oZhOHV6Q==
-----END PUBLIC KEY-----
```

To verify follow the instructions provided by Cosign: <https://docs.sigstore.dev/cosign/verifying/verify/>

## GPG

All Linux packages should be GPG-signed using the following [key](https://raw.githubusercontent.com/telemetryforge/agent/refs/heads/main/gpg.pub):

```text
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEaSmJyBYJKwYBBAHaRw8BAQdA49lnSs+5DCnHIelZ+tO0o++/XTtJ4WLAcdKJ
AuTe0Za0GUZsdWVudERvIDxpbmZvQGZsdWVudC5kbz6ImQQTFgoAQRYhBH1kJTNw
on+ay1bJRnPLZuBWY2diBQJpKYnIAhsDBQkFo5qABQsJCAcCAiICBhUKCQgLAgQW
AgMBAh4HAheAAAoJEHPLZuBWY2diDyMBAKN68HcG0W3/I1Pyfpe5QF6vB+AJ7MzU
rX2g1aO+ZKvjAP0RCtRO6/ekjJz7goM7Qf8HXMo9LMy5uibbVfvbpd8eArg4BGkp
icgSCisGAQQBl1UBBQEBB0Cd6zD8Ah9Wq6BRu6mWddUm/1kvrc4G1rLsx3cpfovG
LAMBCAeIfgQYFgoAJhYhBH1kJTNwon+ay1bJRnPLZuBWY2diBQJpKYnIAhsMBQkF
o5qAAAoJEHPLZuBWY2diCT0BAPuC/5xN4aekvoJkrHxViQx322cCBygXtm1BaKA0
ctVJAQD3kxej3zpHqNnpq+pIuCbU3hGa9aTslQxVDT15bMenDg==
=VZR0
-----END PGP PUBLIC KEY BLOCK-----
```

The fingerprint looks like this:

```text
pub   ed25519 2025-11-28 [SC] [expires: 2028-11-27]
      7D64 2533 70A2 7F9A CB56  C946 73CB 66E0 5663 6762
uid           [ultimate] FluentDo <info@fluent.do>
sub   cv25519 2025-11-28 [E] [expires: 2028-11-27]
```

In addition we generate `sha256` checksums for all packages and sign those files as well for all targets.

This information is for releases `v25.12` and `v25.10.8` onwards, for earlier releases please contact us.

## CVEs

We triage and resolve all CVEs reported against the Agent (and to some degree OSS too), please see [this page](./security/cves.md).

We provide triaged CVE reports both as a [web page](./security/triaged.md) or a [VEX endpoint](./security/vex.json) for easy inclusion in security tooling deployed in your infrastructure.

The VEX endpoint can be downloaded and used like so:

```shell
curl -sSfLO https://docs.fluent.do/security/vex.json
trivy image fluent/fluent-bit:4.0.9 --vex vex.json
grype fluent/fluent-bit:4.0.9 --vex vex.json
```

## Build and binary security

### Security Hardening Features

- SBOM with pinned dependency versions and checksums.
- Official builds are all signed via Sigstore and GPG keys.
- Memory safety monitored via Valgrind/AddressSanitizer in CI and testing.
- Disable all remote interfaces by default (HTTP/gRPC APIs).
- All remote interfaces require explicit opt-in and authentication by default.

### Compiler Security Flags (Enabled by Default)

All release builds are compiled with comprehensive security hardening:

- **Stack Protector Strong** (`-fstack-protector-strong`) - Enhanced buffer overflow detection
- **Buffer Size Protection** (`--param ssp-buffer-size=4`) - Protects buffers ≥4 bytes
- **FORTIFY_SOURCE Level 2** (`-D_FORTIFY_SOURCE=2`) - Runtime bounds checking
- **Integer Overflow Trapping** (`-ftrapv`) - Traps signed integer overflow
- **Position Independent Executable** (PIE/ASLR) - Address space layout randomization

### Linker Security (Linux)

- **Full RELRO** (`-Wl,-z,relro,-z,now`) - GOT/PLT protection
- **Non-Executable Stack** (`-Wl,-z,noexecstack`) - Prevents stack execution (NX bit)

### Attack Surface Reduction

To minimize attack surface and binary size, the following 17 plugins are **disabled by default**:

#### Disabled Input Plugins (9 total)

- `FLB_IN_CALYPTIA_FLEET` - Calyptia fleet management (vendor-specific)
- `FLB_IN_DOCKER` - Docker container metrics
- `FLB_IN_DOCKER_EVENTS` - Docker events monitoring
- `FLB_IN_EXEC_WASI` - WebAssembly System Interface executor
- `FLB_IN_MQTT` - MQTT broker input
- `FLB_IN_NETIF` - Network interface statistics
- `FLB_IN_NGINX_EXPORTER_METRICS` - Nginx metrics exporter
- `FLB_IN_SERIAL` - Serial port input
- `FLB_IN_THERMAL` - Thermal sensors monitoring

#### Disabled Filter Plugins (5 total)

- `FLB_FILTER_ALTER_SIZE` - Record size alteration
- `FLB_FILTER_CHECKLIST` - Checklist validation
- `FLB_FILTER_GEOIP2` - GeoIP2 location enrichment (includes MaxMind database)
- `FLB_FILTER_NIGHTFALL` - Nightfall DLP scanning (vendor-specific)
- `FLB_FILTER_WASM` - WebAssembly filter

#### Disabled Output Plugins (3 total)

- `FLB_OUT_CALYPTIA` - Calyptia monitoring (vendor-specific)
- `FLB_OUT_LOGDNA` - LogDNA/Mezmo service (vendor-specific)
- `FLB_OUT_TD` - Treasure Data (vendor-specific)
- `FLB_OUT_VIVO_EXPORTER` - Vivo exporter (vendor-specific)

### Additional Disabled Features

- `FLB_STREAM_PROCESSOR` - SQL stream processing (reduces complexity)
- `FLB_WASM` - WebAssembly runtime support
- `FLB_ZIG` - Zig language integration
- `FLB_PROXY_GO` - Go plugin support
- `FLB_SHARED_LIB` - Shared library build (static preferred)
- `FLB_EXAMPLES` - Example binaries
- `FLB_CHUNK_TRACE` - Debug chunk tracing
