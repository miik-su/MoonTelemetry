# Fixture provenance

The three JSON fixtures are copied without alteration from
`moonbit-community/opentelemetry.mbt`, `integration/otlp/expected/{signal}/http_json.json`
(0.1.8 source retrieved 2026-11-08). Copyright MoonBit community contributors;
Apache-2.0, see the root LICENSE. They are SDK integration golden payloads, not
output invented by the collector. The integration test sends each as both JSON
and protobuf through real HTTP, processors, and two exporter destinations.
