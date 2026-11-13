# Expanded synthetic OTLP models

These three fixtures are original MoonTelemetry test data, licensed Apache-2.0.
They contain synthetic service names, IDs and values, with no customer telemetry.
They are distinct from the unchanged upstream SDK golden fixtures one directory up.

| File | Records | Features |
| --- | ---: | --- |
| logs.json | 4 logs | Multiple resources/scopes/schema URLs, severity 1/9/17/24, string/bool/int/double/bytes/array/kvlist AnyValue, Int64 and UInt64 timestamp boundaries |
| metrics.json | 5 points | Gauge, Sum, Histogram, ExponentialHistogram, Summary; Exemplar; negative zigzag offset; Int64 min/max and UInt64 max |
| traces.json | 3 spans | Cross-service parent/child chain, links, events, scope/resource attributes and differing schema URLs |

`tests/external` runs each fixture through both ingress and egress HTTP encodings
against official Go Collector 0.165.0 and compares normalized model contents.
These are protocol model fixtures, not statistically realistic time-series data.
Metric business semantics are outside the structural forwarding contract.
