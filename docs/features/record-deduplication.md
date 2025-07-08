# Record Deduplication

## Overview

The record deduplication processor eliminates duplicate log entries in real-time at the source, preventing them from being sent downstream. It uses RocksDB for persistent state management and supports flexible field filtering to handle timestamps and other dynamic fields.

## When to Use

Record deduplication is essential when:

- Applications retry operations and log the same errors multiple times
- Load balancers generate repetitive health check logs
- Network issues cause log shipping retries
- Kubernetes pods restart and replay recent logs
- Multiple collectors process the same log sources

## Key Features

- **Persistent Storage**: Deduplication state survives restarts using RocksDB
- **Configurable TTL**: Automatic expiration of old entries
- **Field Filtering**: Ignore timestamps and other dynamic fields
- **Metrics Integration**: Full Prometheus metrics support

## Configuration

### Basic Configuration

```yaml
processors:
  logs:
    - name: dedup
      ttl: 3600s                    # Time to live for entries
      cache_size: 100M              # RocksDB block cache size
      write_buffer_size: 64M        # Write buffer for batching
      compact_interval: 300s        # Compaction frequency
      ignore_fields:                # Fields to exclude from hash
        - timestamp
        - sequence_number
      ignore_regexes:               # Regex patterns for fields
        - ".*_time$"
        - "^tmp_.*"
```

### Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ttl` | Time | 3600s | Time to live for deduplication entries |
| `cache_size` | Size | 100M | RocksDB block cache size |
| `write_buffer_size` | Size | 64M | Write buffer size for batching |
| `compact_interval` | Time | 300s | Database compaction frequency |
| `ignore_fields` | List | [] | Field names to exclude from deduplication |
| `ignore_regexes` | List | [] | Regex patterns for fields to exclude |

### Field Filtering

The processor can ignore specific fields when calculating record hashes. This is useful for fields that change between otherwise identical records:

- **Exact Match**: Use `ignore_fields` to specify exact field names
- **Pattern Match**: Use `ignore_regexes` for regex-based field matching

### Complete Configuration Example

Here's a full configuration example showing how to enable deduplication with metrics:

```yaml
service:
  flush: 1
  log_level: info
  
  # Enable HTTP server for metrics endpoint
  http_server: on
  http_listen: 0.0.0.0
  http_port: 2020

pipeline:
  inputs:
    - name: tail
      tag: app.logs
      path: /var/log/app/*.log
      refresh_interval: 1s
      processors:
        logs:
          - name: dedup
            ttl: 3600s               # 1 hour TTL
            cache_size: 100M         # 100MB cache
            write_buffer_size: 64M   # 64MB write buffer
            compact_interval: 300s   # Compact every 5 minutes
            
            # Fields to ignore when calculating hash
            ignore_fields:
              - timestamp
              - request_id
              - session_id
            
            # Regex patterns for fields to ignore
            ignore_regexes:
              - ".*_time$"
              - "^trace_.*"
      
    - name: systemd
      tag: system.logs
      systemd_filter: _SYSTEMD_UNIT=nginx.service
      processors:
        logs:
          - name: dedup
            ttl: 7200s               # 2 hour TTL for system logs
            cache_size: 50M          # 50MB cache
            write_buffer_size: 32M   # 32MB write buffer
            compact_interval: 600s   # Compact every 10 minutes

  outputs:
    - name: forward
      match: '*'
      host: log-aggregator.example.com
      port: 24224

# Access metrics:
# curl -s http://localhost:2020/api/v1/metrics/prometheus | grep dedup
#
# Example output:
# fluentbit_processor_dedup_records_processed_total{hostname="server1"} 1000000
# fluentbit_processor_dedup_records_removed_total{hostname="server1"} 450000
# fluentbit_processor_dedup_records_kept_total{hostname="server1"} 550000
# fluentbit_processor_dedup_disk_size_bytes{hostname="server1"} 52428800
# fluentbit_processor_dedup_live_data_size_bytes{hostname="server1"} 45000000
# fluentbit_processor_dedup_compactions_total{hostname="server1"} 12
```

## Performance

The deduplication processor is designed for high-throughput log processing:

- **Throughput**: Processes over 2 million records per second
- **Latency**: Sub-microsecond deduplication checks
- **Memory**: Configurable cache with 100MB default

The processor uses bloom filters and hash indexing to minimize disk I/O, ensuring minimal impact on your log pipeline performance.

## Monitoring and Observability

### Prometheus Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `fluentbit_processor_dedup_records_processed_total` | Counter | Total number of records processed by the deduplication processor |
| `fluentbit_processor_dedup_records_removed_total` | Counter | Total number of duplicate records removed |
| `fluentbit_processor_dedup_records_kept_total` | Counter | Total number of unique records kept |
| `fluentbit_processor_dedup_disk_size_bytes` | Gauge | Total size of RocksDB SST files on disk in bytes |
| `fluentbit_processor_dedup_live_data_size_bytes` | Gauge | Size of live data in RocksDB (excluding expired entries) |
| `fluentbit_processor_dedup_compactions_total` | Counter | Total number of database compactions performed |


## Use Cases

### 1. Kubernetes Log Collection

Ignore pod-specific fields while deduplicating application logs:
```yaml
ignore_fields:
  - kubernetes.pod_id
  - kubernetes.container_id
ignore_regexes:
  - "kubernetes\\.labels\\.pod-template-hash"
```

### 2. Load Balancer Access Logs

Deduplicate health check spam:
```yaml
ignore_fields:
  - timestamp
  - request_id
  - source_ip
```

### 3. Application Error Logs

Catch repeated errors while preserving first occurrence:
```yaml
ttl: 3600s  # 1 hour window
ignore_fields:
  - timestamp
  - thread_id
  - request_context
```


## Future Work

- **Probabilistic Structures**: HyperLogLog for memory-efficient cardinality estimation
- **Smart Field Detection**: Auto-identify high-cardinality fields to ignore
- **Dedup Analytics**: Track duplicate patterns and sources
- **Conditional Logic**: Apply different TTLs based on content

## Getting Started

1. Enable the deduplication processor in your Fluent Bit configuration
2. Attach it to any input that experiences duplicate logs  
3. Configure TTL and field filtering based on your use case
4. Monitor deduplication effectiveness via Prometheus metrics

For additional support and enterprise features, contact the FluentDo team.