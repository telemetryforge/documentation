# Log Sampling Processor

The log sampling processor provides configurable strategies to sample log streams, helping manage log volume and costs while maintaining visibility into your applications.

## Overview

The log sampling processor supports three sampling strategies:

- **Fixed Window**: Samples first N logs per fixed time window
- **Sliding Window**: Maintains rolling rate limit over time  
- **Exponential Decay**: Progressively reduces sampling rate

## Use Cases

- Managing high-volume debug logs
- Reducing ingestion costs while maintaining visibility
- Progressive sampling for long-running applications
- Protecting downstream systems from log bursts

## Configuration

### Fixed Window Sampling

Samples the first N logs in each fixed time window. Once the limit is reached, logs are dropped until the next window begins.

```yaml
processors:
  logs:
    - name: log_sampling
      window_type: fixed
      window_size: 10  # 10 second windows
      max_logs_per_window: 100  # Keep first 100 logs per window
```

### Sliding Window Sampling

Maintains a rolling window that continuously moves forward in time, ensuring a maximum number of logs in any given time period.

```yaml
processors:
  logs:
    - name: log_sampling
      window_type: sliding
      window_size: 30  # 30 second rolling window
      max_logs_per_window: 500  # Max 500 logs in any 30 second period
```

### Exponential Decay Sampling

Progressively reduces the sampling rate over time using an exponential decay function.

```yaml
processors:
  logs:
    - name: log_sampling
      window_type: exponential
      decay_base_rate: 0.8  # Start at 80% sampling
      decay_factor: 0.7  # Reduce to 70% of previous rate
      decay_interval: 60  # Every 60 seconds
```

## Configuration Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `window_type` | string | Sampling strategy: `fixed`, `sliding`, or `exponential` | Required |
| `window_size` | integer | Window duration in seconds (for fixed/sliding) | 60 |
| `max_logs_per_window` | integer | Maximum logs per window (for fixed/sliding) | 1000 |
| `decay_base_rate` | float | Initial sampling rate (for exponential, 0.0-1.0) | 0.8 |
| `decay_factor` | float | Rate reduction factor (for exponential, 0.0-1.0) | 0.7 |
| `decay_interval` | integer | Decay interval in seconds (for exponential) | 60 |

## Examples

### High-Volume Debug Log Management

```yaml
processors:
  logs:
    - name: log_sampling
      window_type: fixed
      window_size: 5
      max_logs_per_window: 50
```

This configuration keeps only the first 50 logs every 5 seconds, useful for debugging without overwhelming storage.

### API Rate Limiting Protection

```yaml
processors:
  logs:
    - name: log_sampling
      window_type: sliding
      window_size: 60
      max_logs_per_window: 1000
```

Ensures no more than 1000 logs are forwarded in any 60-second period, protecting downstream APIs from bursts.

### Long-Running Application Sampling

```yaml
processors:
  logs:
    - name: log_sampling
      window_type: exponential
      decay_base_rate: 1.0  # Start with 100% sampling
      decay_factor: 0.5  # Halve the rate each interval
      decay_interval: 300  # Every 5 minutes
```

Starts with full sampling and progressively reduces the rate, ideal for applications that generate more logs during startup.