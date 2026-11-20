///|
fn parse_self_metrics(value : Json?) -> SelfMetricsSpec? raise {
  guard value is Some(value) else { return None }
  let path = "service.self_metrics"
  let map = object(value, path)
  fields(map, ["exporter", "instance_id", "interval_ms"], path)
  let exporter = text(map, "exporter", "", path)
  if component_type(exporter) != "otlp" {
    error(path + ".exporter", "requires a dedicated OTLP/HTTP exporter")
  }
  let instance_id = text(map, "instance_id", "", path)
  if instance_id.is_empty() ||
    instance_id.length() > 128 ||
    !instance_id
    .iter()
    .all(c => {
      (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '-' ||
      c == '_' ||
      c == '.'
    }) {
    error(
      path + ".instance_id",
      "expected 1–128 ASCII letters, digits, dots, hyphens or underscores",
    )
  }
  Some({
    exporter,
    instance_id,
    interval_ms: number(map, "interval_ms", 30000, path, min=1000, max=3600000),
  })
}
