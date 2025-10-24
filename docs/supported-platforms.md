# Supported Platforms

The FluentDo agent supports all major architectures including `x86_64` and `arm64` as well as optionally `riscv64`, `s390x` and others.

Releases can be found or watched here: <https://github.com/FluentDo/agent>

Please [contact us](mailto:info@fluent.do) for full details.

## Kubernetes versions

We support all mainstream Kubernetes providers including Digital Ocean, Openshift, EKS (AWS), GKE (Google), AKS (Microsoft) and all their supported versions as well.

We test against a matrix of vanilla Kubernetes versions along with the various distributions and configurations required by customers to guarantee the use cases they require are supported.

## Container images

Hardened container images are provided for:

- Openshift via `quay.io`
- AWS via ECS
- Google Cloud via Artifact Registry
- All images are in docker.io and ghcr.io as well
- [Red Hat catalog](https://catalog.redhat.com/software/container-stacks/detail/68cfeb03e65464ef8fd4d608)

## Native installation

Packages as well as public VM images (AMIs) are available for the following Enterprise OS Versions:

|OS | Versions Supported | Notes |
|---|--------------------|-------|
|RHEL|7.x, 8.x, 9.x, 10.x|RHEL compatibility via CentOS 7 then Alma Linux 8-10. |
|CentOS|6.x, 7.x||
|CentOS Stream|8, 9, 10|Upstream dependencies no longer guaranteed to be RHEL-compatible.|
|Alma Linux| 8, 9, 10| RHEL–compatible without breaking changes from CentOS stream. |
|Rocky Linux| 8, 9, 10| RHEL–compatible without breaking changes from CentOS stream. |
|SUSE Linux Enterprise Server (SLES)|12, 15||
|Ubuntu LTS|18.04, 20.04, 22.04, 24.04||
|Debian|10,11,12,13||
|Windows|2022,2025| Server versions but compatible with desktop equivalents |

Part of our support package includes testing against the specific use cases or configurations you may require.

Installation of packages is available via [https://packages.fluent.do](https://packages.fluent.do/index.html).
