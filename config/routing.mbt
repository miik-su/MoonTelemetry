///|
fn parse_routing(
  value : Json?,
  exporters : Array[String],
  path : String,
) -> RoutingSpec? raise {
  guard value is Some(value) else { return None }
  let map = object(value, path)
  fields(map, ["rules", "default_exporters"], path)
  guard map.get("rules") is Some(Array(entries)) &&
    entries.length() > 0 &&
    entries.length() <= 16 &&
    exporters.length() <= 16 else {
    raise @component.Configuration(
      path + ": expected 1–16 rules and at most 16 attached exporters",
    )
  }
  let default_exporters = names(map, "default_exporters", path)
  if default_exporters.is_empty() ||
    default_exporters.any(id => !exporters.contains(id)) {
    error(path, "fallback must name at least one attached exporter")
  }
  let rules = []
  for i, value in entries {
    let entry_path = path + ".rules[\{i}]"
    let entry = object(value, entry_path)
    fields(entry, ["exporter", "condition"], entry_path)
    let target = text(entry, "exporter", "", entry_path)
    if !exporters.contains(target) {
      error(entry_path, "rule must name an attached exporter")
    }
    let filter = @processor.Filter::parse(
      entry.get("condition").unwrap_or(Json::null()),
    ) catch {
      _ =>
        raise @component.Configuration(
          entry_path + ": invalid filter condition",
        )
    }
    rules.push((target, filter))
  }
  for id in exporters {
    if !default_exporters.contains(id) && !rules.any(rule => rule.0 == id) {
      error(path, "unused attached exporter " + id)
    }
  }
  Some({ rules, default_exporters, })
}
