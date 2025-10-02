# Git Configuration Auto-Reload

The `git_config` custom plugin enables automatic configuration reloading by monitoring a Git repository for changes. When changes are detected, Fluent Bit automatically reloads its configuration without manual intervention or service restarts.

## Overview

This plugin continuously polls a Git repository at a configurable interval. When it detects that the remote repository's commit SHA has changed, it:

1. Syncs the repository to a local clone
2. Extracts the specified configuration file
3. Triggers a hot-reload of Fluent Bit with the new configuration

State is persisted between restarts, preventing unnecessary reloads when Fluent Bit restarts with an unchanged configuration.

The plugin also exposes Prometheus-compatible metrics for monitoring repository polling and reload operations.

## Configuration Options

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `repo` | String | Yes | - | Git repository URL (HTTPS, SSH, or file://) |
| `ref` | String | No | `main` | Git reference: branch name, tag, or commit SHA |
| `path` | String | Yes | - | Path to configuration file within the repository |
| `clone_path` | String | No | `/tmp/fluentbit-git-repo` | Local directory for git clone and state storage |
| `poll_interval` | Integer | No | `60` | Polling interval in seconds to check for updates |


The Git repository URL. Supports multiple protocols:

- **HTTPS**: `https://github.com/user/repo.git`
- **SSH**: `git@github.com:user/repo.git`
- **Local file**: `file:///path/to/repo`

For private repositories:
- **HTTPS**: Use personal access tokens in the URL: `https://token@github.com/user/repo.git`
- **SSH**: Configure SSH keys in `~/.ssh/` (requires `id_rsa` or `id_ed25519`)

#### `ref`

The Git reference to track. Can be:

- **Branch name**: `main`, `develop`, `production`
- **Tag**: `v1.0.0`, `release-2024`
- **Commit SHA**: `abc123def456...` (full or short SHA)

The plugin monitors this reference for changes. When the commit SHA at this ref changes, a reload is triggered.

#### `path`

Path to the configuration file within the repository, relative to the repository root.

Examples:
- `fluent-bit.yaml`
- `config/production.yaml`
- `environments/prod/fluent-bit.conf`

#### `clone_path`

Local directory where:
- The Git repository is cloned
- SHA-based configuration files are stored
- The state file (`.last_sha`) is stored

The directory will be created if it doesn't exist. Must be writable by the Fluent Bit process.

#### `poll_interval`

How frequently (in seconds) to check the remote repository for changes.

Recommended values:
- **Development/Testing**: 5-10 seconds
- **Production**: 60-300 seconds

## Example Configurations

### Example 1: Monitor Branch (Basic)

Monitor the `main` branch of a public HTTPS repository with default settings:

```yaml
service:
  flush: 1
  daemon: off
  log_level: info
  http_server: on
  http_listen: 0.0.0.0
  http_port: 2020

customs:
  - name: git_config
    repo: https://github.com/myorg/fluent-bit-configs.git
    ref: main
    path: fluent-bit.yaml
    clone_path: /tmp/fluentbit-git
    poll_interval: 60
```

**Use case**: Track the latest configuration on the main branch. Any commits pushed to `main` will trigger a reload within 60 seconds.

### Example 2: Monitor Specific Commit SHA

Pin to a specific commit SHA and poll frequently for development:

```yaml
service:
  flush: 1
  daemon: off
  log_level: debug
  http_server: on
  http_listen: 0.0.0.0
  http_port: 2020

customs:
  - name: git_config
    repo: https://github.com/myorg/configs.git
    ref: a3f5c89d124b3e567890abcdef123456789abcde
    path: config/development.yaml
    clone_path: /var/lib/fluent-bit/git-clone
    poll_interval: 10
```

**Use case**: Lock configuration to a specific tested commit during development. Fast polling (10s) enables quick iteration. Update `ref` to a new commit SHA to deploy changes.

### Example 3: Monitor with Custom Polling Interval

Adjust polling frequency based on environment needs:

```yaml
service:
  flush: 1
  daemon: off
  log_level: info
  http_server: on
  http_listen: 0.0.0.0
  http_port: 2020

customs:
  - name: git_config
    repo: https://github.com/myorg/configs.git
    ref: production
    path: fluent-bit.yaml
    clone_path: /var/lib/fluent-bit/git-config
    poll_interval: 300  # Check every 5 minutes

pipeline:
  outputs:
    - name: stdout
      match: '*'
```

**Use case**: Production environment with infrequent configuration changes. Slower polling (300s) reduces network overhead while still detecting updates within an acceptable timeframe.

## How It Works

### State Persistence

The plugin stores the last processed commit SHA in a state file:
```
{clone_path}/.last_sha
```

This state file:
- Persists across Fluent Bit restarts
- Prevents unnecessary reloads when restarting with unchanged configuration
- Contains a 40-character SHA-1 commit hash

### Hot Reload Process

When a configuration change is detected:

1. **Sync**: Clone or pull the latest changes from the repository
2. **Extract**: Read the specified configuration file from the repository
3. **Write**: Write the configuration to `{clone_path}/{sha}.yaml`
4. **Save State**: Update `.last_sha` with the new commit SHA
5. **Reload**: Send `SIGHUP` signal (Unix) or `CTRL_BREAK` event (Windows) to trigger Fluent Bit reload
6. **Pause**: Collector is paused during reload to prevent conflicts

### Change Detection

The plugin uses Git commit SHAs for change detection:
- Fetches the commit SHA at the specified `ref`
- Compares with the last processed SHA from state file
- If different, triggers sync and reload

This approach works with:
- Branch updates (SHA changes when new commits are pushed)
- Tag updates (if tag is moved to a different commit)
- Direct SHA monitoring (only reloads if you manually update the `ref` parameter)

## Metrics and Monitoring

The plugin exposes Prometheus-compatible metrics for monitoring repository polling and reload operations.

### Available Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `fluentbit_git_config_last_poll_timestamp_seconds` | Gauge | `name` | Unix timestamp of the last repository poll |
| `fluentbit_git_config_last_reload_timestamp_seconds` | Gauge | `name` | Unix timestamp of the last configuration reload |
| `fluentbit_git_config_poll_errors_total` | Counter | `name` | Total number of repository poll errors |
| `fluentbit_git_config_sync_errors_total` | Counter | `name` | Total number of git sync errors |
| `fluentbit_git_config_info` | Gauge | `sha`, `repo` | Plugin information with current SHA and repository |

### Accessing Metrics

Metrics are automatically exposed when the HTTP server is enabled. Access them at the `/api/v1/metrics/prometheus` endpoint:

```bash
curl http://localhost:2020/api/v1/metrics/prometheus
```

Example output:
```
# HELP fluentbit_git_config_last_poll_timestamp_seconds Unix timestamp of last repository poll
# TYPE fluentbit_git_config_last_poll_timestamp_seconds gauge
fluentbit_git_config_last_poll_timestamp_seconds{name="git_config.0"} 1696349234

# HELP fluentbit_git_config_last_reload_timestamp_seconds Unix timestamp of last configuration reload
# TYPE fluentbit_git_config_last_reload_timestamp_seconds gauge
fluentbit_git_config_last_reload_timestamp_seconds{name="git_config.0"} 1696349234

# HELP fluentbit_git_config_poll_errors_total Total number of repository poll errors
# TYPE fluentbit_git_config_poll_errors_total counter
fluentbit_git_config_poll_errors_total{name="git_config.0"} 0

# HELP fluentbit_git_config_sync_errors_total Total number of git sync errors
# TYPE fluentbit_git_config_sync_errors_total counter
fluentbit_git_config_sync_errors_total{name="git_config.0"} 0

# HELP fluentbit_git_config_info Git config plugin info
# TYPE fluentbit_git_config_info gauge
fluentbit_git_config_info{sha="abc123def",repo="https://github.com/myorg/configs.git"} 1
```

### Using Metrics for Alerting

You can use these metrics with monitoring systems like Prometheus and Grafana:

**Prometheus Alert Examples:**
```yaml
groups:
  - name: fluent_bit_git_config
    rules:
      - alert: GitConfigStale
        expr: (time() - fluentbit_git_config_last_poll_timestamp_seconds) > 300
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Git configuration check is stale"
          description: "No git config poll in the last 5 minutes for {{ $labels.name }}"

      - alert: GitConfigPollErrors
        expr: rate(fluentbit_git_config_poll_errors_total[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Git configuration poll errors"
          description: "{{ $labels.name }} is experiencing poll errors"

      - alert: GitConfigSyncErrors
        expr: rate(fluentbit_git_config_sync_errors_total[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Git configuration sync errors"
          description: "{{ $labels.name }} is experiencing sync errors"

      - alert: GitConfigNotReloaded
        expr: (time() - fluentbit_git_config_last_reload_timestamp_seconds) > 86400
        for: 10m
        labels:
          severity: info
        annotations:
          summary: "Git configuration hasn't been reloaded recently"
          description: "No config reload in the last 24 hours for {{ $labels.name }} (may be normal if no changes)"
```

## Authentication

### HTTPS with Personal Access Token

```yaml
customs:
  - name: git_config
    repo: https://ghp_yourtoken123456@github.com/myorg/private-repo.git
    ref: main
    path: fluent-bit.yaml
```

### SSH with Key Authentication

```yaml
customs:
  - name: git_config
    repo: git@github.com:myorg/private-repo.git
    ref: main
    path: fluent-bit.yaml
```

Requirements:
- SSH keys configured in `~/.ssh/id_rsa` or `~/.ssh/id_ed25519`
- Proper permissions: `chmod 600 ~/.ssh/id_rsa`
- Known hosts configured: `ssh-keyscan github.com >> ~/.ssh/known_hosts`

## Error Handling

The plugin is designed to be resilient to transient errors:

- **Network failures**: Logged as errors, polling continues, `poll_errors_total` incremented
- **Git operation failures**: Logged as errors, retry on next poll, `sync_errors_total` incremented
- **Invalid configuration files**: Reload skipped, polling continues
- **Missing files**: Logged as errors, polling continues

## Performance Considerations

### Polling Interval

- **Too frequent**: Increases network traffic and CPU usage checking for updates
- **Too infrequent**: Delays detection of configuration changes

Choose based on your requirements:
- Critical production systems: 60-120 seconds
- Active development: 5-10 seconds
- Stable environments: 300-600 seconds

### Git Clone Path

- Use fast local storage (avoid network mounts)
- Ensure adequate disk space for repository size
- Clean up old clones if disk space is limited

### Repository Size

Large repositories with extensive history may slow initial cloning. Consider:
- Using shallow clones (future enhancement)
- Keeping configuration repositories small and focused
- Using separate repositories for configuration vs. application code

## Troubleshooting


### Authentication Failures

For SSH:
```bash
# Test SSH connection
ssh -T git@github.com

# Check key permissions
ls -la ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
```

For HTTPS with token:
```bash
# Test git access
git ls-remote https://token@github.com/user/repo.git
```

### Changes Not Detected

Enable debug logging to see polling activity:
```yaml
service:
  log_level: debug
```

Check:
- Remote repository actually has new commits
- `ref` points to the branch/tag you expect
- Polling interval hasn't elapsed yet
- State file permissions: `ls -la {clone_path}/.last_sha`
- Metrics: `curl http://localhost:2020/api/v1/metrics/prometheus | grep git_config`

### Reload Failures

Check:
- Configuration file syntax is valid
- All referenced plugins are available
- File paths and permissions are correct
- System allows process to send signals (SIGHUP)

### High Error Rates

Monitor the error metrics:
```bash
curl -s http://localhost:2020/api/v1/metrics/prometheus | grep -E "git_config_(poll|sync)_errors"
```

Common causes:
- Network connectivity issues
- Authentication failures
- Repository access problems
- Disk space issues in clone_path

## Security Considerations

1. **Credentials**:
   - Never commit credentials to repositories
   - Use environment variables or secret management for tokens
   - Rotate SSH keys and tokens regularly

2. **State File**:
   - Contains only the commit SHA (no sensitive data)
   - Ensure `clone_path` permissions prevent unauthorized access

3. **Configuration Files**:
   - Validate configuration before pushing to Git
   - Use branch protection rules to prevent unauthorized changes
   - Consider using signed commits for added security

4. **Network Security**:
   - Use SSH over HTTPS when possible
   - Ensure TLS certificate validation is enabled
   - Consider using private networks for sensitive configurations

## Limitations

- Windows support uses `CTRL_BREAK_EVENT` instead of `SIGHUP`
- Only monitors a single file per plugin instance (use multiple instances for multiple files)
- Does not support git submodules
- Requires network access to remote repository during polling
- Configuration file must be tracked in Git (untracked files are not detected)
- Metrics require HTTP server to be enabled (`http_server: on`)

## See Also

- [Fluent Bit Hot Reload](https://docs.fluentbit.io/manual/administration/hot-reload)
- [Git Configuration Best Practices](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit)
- [Custom Plugins Overview](https://docs.fluentbit.io/manual/development/custom-plugins)
- [Fluent Bit Metrics](https://docs.fluentbit.io/manual/administration/monitoring)