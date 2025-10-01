# Git Configuration Auto-Reload

The `git_config` input plugin enables automatic configuration reloading by monitoring a Git repository for changes. When changes are detected, Fluent Bit automatically reloads its configuration without manual intervention or service restarts.

## Overview

This plugin continuously polls a Git repository at a configurable interval. When it detects that the remote repository's commit SHA has changed, it:

1. Syncs the repository to a local clone
2. Extracts the specified configuration file
3. Triggers a hot-reload of Fluent Bit with the new configuration

State is persisted between restarts, preventing unnecessary reloads when Fluent Bit restarts with an unchanged configuration.

## Configuration Options

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `git_url` | String | Yes | - | Git repository URL (HTTPS, SSH, or file://) |
| `git_ref` | String | Yes | `main` | Git reference: branch name, tag, or commit SHA |
| `config_file` | String | Yes | - | Path to configuration file within the repository |
| `git_clone_path` | String | No | `/tmp/fluentbit-git-repo` | Local directory for git clone and state storage |
| `poll_interval_sec` | Integer | No | `60` | Polling interval in seconds to check for updates |

### Parameter Details

#### `git_url`

The Git repository URL. Supports multiple protocols:

- **HTTPS**: `https://github.com/user/repo.git`
- **SSH**: `git@github.com:user/repo.git`
- **Local file**: `file:///path/to/repo`

For private repositories:
- **HTTPS**: Use personal access tokens in the URL: `https://token@github.com/user/repo.git`
- **SSH**: Configure SSH keys in `~/.ssh/` (requires `id_rsa` or `id_ed25519`)

#### `git_ref`

The Git reference to track. Can be:

- **Branch name**: `main`, `develop`, `production`
- **Tag**: `v1.0.0`, `release-2024`
- **Commit SHA**: `abc123def456...` (full or short SHA)

The plugin monitors this reference for changes. When the commit SHA at this ref changes, a reload is triggered.

#### `config_file`

Path to the configuration file within the repository, relative to the repository root.

Examples:
- `fluent-bit.yaml`
- `config/production.yaml`
- `environments/prod/fluent-bit.conf`

#### `git_clone_path`

Local directory where:
- The Git repository is cloned
- The state file (`.git_last_sha`) is stored

The directory will be created if it doesn't exist. Must be writable by the Fluent Bit process.

#### `poll_interval_sec`

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

pipeline:
  inputs:
    - name: git_config
      git_url: https://github.com/myorg/fluent-bit-configs.git
      git_ref: main
      config_file: fluent-bit.yaml
      git_clone_path: /tmp/fluentbit-git
      poll_interval_sec: 60

  outputs:
    - name: stdout
      match: '*'
```

**Use case**: Track the latest configuration on the main branch. Any commits pushed to `main` will trigger a reload within 60 seconds.

### Example 2: Monitor Specific Commit SHA

Pin to a specific commit SHA and poll frequently for development:

```yaml
service:
  flush: 1
  daemon: off
  log_level: debug

pipeline:
  inputs:
    - name: git_config
      git_url: https://github.com/myorg/configs.git
      git_ref: a3f5c89d124b3e567890abcdef123456789abcde
      config_file: config/development.yaml
      git_clone_path: /var/lib/fluent-bit/git-clone
      poll_interval_sec: 10

  outputs:
    - name: stdout
      match: '*'
```

**Use case**: Lock configuration to a specific tested commit during development. Fast polling (10s) enables quick iteration. Update `git_ref` to a new commit SHA to deploy changes.

### Example 3: Monitor with Custom Polling Interval

Adjust polling frequency based on environment needs:

```yaml
service:
  flush: 1
  daemon: off
  log_level: info

pipeline:
  inputs:
    - name: git_config
      git_url: https://github.com/myorg/configs.git
      git_ref: production
      config_file: fluent-bit.yaml
      git_clone_path: /var/lib/fluent-bit/git-config
      poll_interval_sec: 300  # Check every 5 minutes

  outputs:
    - name: stdout
      match: '*'
```

**Use case**: Production environment with infrequent configuration changes. Slower polling (300s) reduces network overhead while still detecting updates within an acceptable timeframe.

## How It Works

### State Persistence

The plugin stores the last processed commit SHA in a state file:
```
{git_clone_path}/.git_last_sha
```

This state file:
- Persists across Fluent Bit restarts
- Prevents unnecessary reloads when restarting with unchanged configuration
- Contains a 40-character SHA-1 commit hash

### Hot Reload Process

When a configuration change is detected:

1. **Sync**: Clone or pull the latest changes from the repository
2. **Extract**: Read the specified configuration file from the repository
3. **Write**: Write the configuration to `{git_clone_path}/{config_file}`
4. **Save State**: Update `.git_last_sha` with the new commit SHA
5. **Reload**: Send `SIGHUP` signal (Unix) or `CTRL_BREAK` event (Windows) to trigger Fluent Bit reload
6. **Pause**: Collector is paused during reload to prevent conflicts

### Change Detection

The plugin uses Git commit SHAs for change detection:
- Fetches the commit SHA at the specified `git_ref`
- Compares with the last processed SHA from state file
- If different, triggers sync and reload

This approach works with:
- Branch updates (SHA changes when new commits are pushed)
- Tag updates (if tag is moved to a different commit)
- Direct SHA monitoring (only reloads if you manually update the `git_ref` parameter)

## Authentication

### HTTPS with Personal Access Token

```yaml
inputs:
  - name: git_config
    git_url: https://ghp_yourtoken123456@github.com/myorg/private-repo.git
    git_ref: main
    config_file: fluent-bit.yaml
```

### SSH with Key Authentication

```yaml
inputs:
  - name: git_config
    git_url: git@github.com:myorg/private-repo.git
    git_ref: main
    config_file: fluent-bit.yaml
```

Requirements:
- SSH keys configured in `~/.ssh/id_rsa` or `~/.ssh/id_ed25519`
- Proper permissions: `chmod 600 ~/.ssh/id_rsa`
- Known hosts configured: `ssh-keyscan github.com >> ~/.ssh/known_hosts`

## Error Handling

The plugin is designed to be resilient to transient errors:

- **Network failures**: Logged as errors, polling continues
- **Git operation failures**: Logged as errors, retry on next poll
- **Invalid configuration files**: Reload skipped, polling continues
- **Missing files**: Logged as errors, polling continues

The collector will never stop due to temporary failures. Check logs for error details.

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

### Plugin Not Loading

Check that libgit2 is available:
```bash
ldd /path/to/fluent-bit | grep git2
```

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
- `git_ref` points to the branch/tag you expect
- Polling interval hasn't elapsed yet
- State file permissions: `ls -la {git_clone_path}/.git_last_sha`

### Reload Failures

Check:
- Configuration file syntax is valid
- All referenced plugins are available
- File paths and permissions are correct
- System allows process to send signals (SIGHUP)

## Security Considerations

1. **Credentials**:
   - Never commit credentials to repositories
   - Use environment variables or secret management for tokens
   - Rotate SSH keys and tokens regularly

2. **State File**:
   - Contains only the commit SHA (no sensitive data)
   - Ensure `git_clone_path` permissions prevent unauthorized access

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

## See Also

- [Fluent Bit Hot Reload](https://docs.fluentbit.io/manual/administration/hot-reload)
- [Git Configuration Best Practices](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit)
- [Input Plugins Overview](https://docs.fluentbit.io/manual/pipeline/inputs)
