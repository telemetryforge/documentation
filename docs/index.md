# FluentDo Agent Documentation

## What is FluentDo Agent?

FluentDo Agent is an **enterprise-hardened distribution of Fluent Bit**, maintained by core OSS maintainers. It delivers production-ready log processing with enhanced security, reduced footprint, and enterprise support.

### Key Differentiators

✅ **70% smaller than OSS Fluent Bit** - Optimized for production deployments  
✅ **Security-hardened by default** - FORTIFY_SOURCE, stack protection, and reduced attack surface  
✅ **24-month LTS support** - Weekly security patches and critical bug fixes  
✅ **Enterprise features** - Advanced deduplication, AI filtering, and compliance tools  
✅ **Fully supported** - Direct access to core Fluent Bit maintainers  

## Documentation

- [Supported Platforms](./supported-platforms.md) - Verified OS and architecture support
- [Version Mapping](./version-mapping.md) - FluentDo to OSS Fluent Bit version alignment
- [Security](./security.md) - Hardening features and CVE management
- [OSS Fluent Bit Docs](https://docs.fluentbit.io) - Core documentation reference

## Enterprise Features

### Performance & Reliability
- **[Log Deduplication](./features/record-deduplication.md)** - Eliminate duplicate logs at source, reducing costs by up to 40%
- **Efficient Storage Buffer** - Advanced filesystem buffering for reliability
- **Tail Sampling** - Smart sampling with OTTL-style logic for high-volume environments

### Data Processing
- **AI-Powered Filtering** - Intelligent log routing and filtering
- **Native Field Flattening** - Prevent field explosion in Elasticsearch/OpenSearch
- **Type Safety** - Automatic type conflict resolution

### Enterprise Hardening
- **Reduced Attack Surface** - 17 vendor-specific plugins disabled by default
- **Security by Default** - All remote interfaces disabled, authentication required
- **Compliance Ready** - FIPS-compliant builds with OpenSSL in FIPS mode

## Build Optimizations

FluentDo Agent is **70% smaller than OSS Fluent Bit** through:

- **Reduced scope** - Only production-essential plugins included
- **Secure defaults** - Vendor-specific and risky plugins disabled
- **Optimized compilation** - Size-focused builds with dead code elimination

[Learn more about build optimizations →](./build-optimizations.md)

## Support & Lifecycle

### Long-Term Support (LTS)

| Component | Timeline | Details |
|-----------|----------|---------|
| **Major Release** | Every 12 months | New features and improvements |
| **Security Updates** | Weekly | CVE patches and critical fixes |
| **Support Window** | 24 months | No breaking changes, full backports |
| **VEX Feed** | Continuous | Automated vulnerability reporting |

## Testing & Quality

### Continuous Validation
- **Daily Security Scans** - Core and dependency vulnerability scanning
- **Integration Testing** - Full regression suite for enterprise scenarios
- **Memory Safety** - Valgrind and AddressSanitizer validation
- **Performance Benchmarks** - Continuous performance regression testing

## Resources

### Technical Documentation
- [Build Optimizations](./build-optimizations.md) - Size and performance improvements
- [Security Hardening](./security.md) - Comprehensive security features
- [Feature Documentation](./features/) - Enterprise feature guides

### Contact

For custom builds, white-label solutions, or enterprise support: **info@fluent.do**