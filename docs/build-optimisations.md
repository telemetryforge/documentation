# Build Optimisations

Our Agent is **~70% smaller than OSS Fluent Bit** through strategic optimisations while maintaining security and performance.

## Optimisation Techniques

### 1. Strategic Plugin Selection

17 vendor-specific and specialized plugins are disabled by default to reduce binary size and attack surface. See [Security Documentation](./security.md#attack-surface-reduction) for the complete list of disabled plugins.

### 2. Compiler Optimisations

- **Size-optimised compilation** (`-Os`) - Optimises for size over speed
- **Function/data sections** (`-ffunction-sections -fdata-sections`) - Enables granular dead code elimination
- **Dead code elimination** - Platform-specific:
  - Linux: `-Wl,--gc-sections`
  - macOS: `-Wl,-dead_strip`
- **Interprocedural optimisation** (IPO/LTO) - Cross-function optimisation and inlining

### 3. Build System Configuration

- **Static binary preferred** - `FLB_SHARED_LIB=OFF` eliminates shared library dependencies
- **Disabled development features**:
  - Examples (`FLB_EXAMPLES=OFF`)
  - Stream processor (`FLB_STREAM_PROCESSOR=OFF`)
  - WASM runtime (`FLB_WASM=OFF`)
  - Zig integration (`FLB_ZIG=OFF`)
  - Go plugin support (`FLB_PROXY_GO=OFF`)
  - Debug chunk tracing (`FLB_CHUNK_TRACE=OFF`)

### 4. Docker Optimisations

- Explicit `CMAKE_BUILD_TYPE=Release` for proper optimisations
- Binary stripping post-compilation (`strip bin/fluent-bit`)
- Minimal base image dependencies (removed `libpq`, `systemd-libs`, `shadow-utils`)

### 5. Platform-Specific Fixes

#### macOS ARM64 LuaJIT Fix

Addresses buildvm crashes on Apple Silicon by isolating LuaJIT compilation from global optimisation flags:

```cmake
# Save and clear optimisation flags for LuaJIT
set(SAVED_CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
set(CMAKE_C_FLAGS "")
set(BUILDVM_COMPILER_FLAGS "-O0")
add_subdirectory("lib/luajit-cmake")
# Restore flags after LuaJIT build
set(CMAKE_C_FLAGS "${SAVED_CMAKE_C_FLAGS}")
```

## Size Impact

| Metric | OSS Fluent Bit | Telemetry Forge Agent | Reduction |
|--------|---------------|----------------|-----------|
| Docker Image Size | ~500MB | ~150MB | ~70% |
| Binary Size | ~50-60MB | ~15-20MB | ~67% |
| Memory Usage | ~50-70MB RSS | ~20-30MB RSS | ~57% |

## Trade-offs

### Functionality vs Size

- Disabled plugins must be explicitly enabled if needed
- Vendor-specific integrations require recompilation

### Performance Considerations

- `-Os` may have minor performance impact vs `-O2`
- IPO/LTO increases build time but improves runtime efficiency
- Static linking increases binary size but simplifies deployment

### Security Benefits

- Reduced attack surface from disabled plugins
- Smaller codebase easier to audit
- Fewer dependencies reduce supply chain risks

## Enabling Disabled Plugins

If you need plugins that are disabled by default, you can:

1. **Request a custom build** from our commercial support with specific plugins enabled
2. **Use OSS Fluent Bit** if vendor-specific plugins are required
3. **Build from source** with your required configuration
