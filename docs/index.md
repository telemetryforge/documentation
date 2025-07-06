# Welcome to FluentDo Agent documentation

The FluentDo Agent is an Enterprise-ready, supported and more secure by default variant of OSS Fluent Bit.
We focus on ensure performance, stability, and compliance.

We include only stable and widely used plugins by default.
We also support tailor-made builds with custom plugin sets or for white-labelling requirements.
We disable unused plugins and developer-only features at compile time, along with using secure defaults for network connections and similar features.

- [Fluent Bit](https://docs.fluentbit.io)
- [Security](./security.md)
- [Supported Platforms](./supported-platforms.md)

We build on OSS Fluent Bit (as core maintainers of OSS) and provide some specific FluentDo enhancements:

- Performant log deduplication at source
- AI-based filtering and routing
- Tail sampling and OTTL-style logic
- Efficient filesystem storage buffer
- Dedicated integration and regression testing

A major long-term support (LTS) release is created every 12 months.
This will then include weekly patch releases for CVEs and critical bugs.
No breaking changes added during the support window and backports will be made for critical features.
End-of-life 24 months after initial release.
