///|
test "filter configuration accepts predicates and rejects legacy mixtures" {
  let source : Json = {
    "receivers": { "otlp": {} },
    "processors": {
      "filter": { "all": [{ "attribute": "secret", "operator": "exists" }] },
    },
    "exporters": { "debug": {} },
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": ["filter"],
          "exporters": ["debug"],
        },
      },
    },
  }
  let _ = @config.parse(source.stringify())
  for
    bad in [
      "{\"key\":\"secret\",\"equals\":true,\"all\":[]}", "{\"all\":[]}", "{\"attribute\":\"secret\",\"operator\":\"script\"}",
    ] {
    guard source is Object(root) else { abort("fixture") }
    root["processors"] = { "filter": @json.parse(bad) }
    assert_true(
      try {
        let _ = @config.parse(Json::object(root).stringify())
        false
      } catch {
        _ => true
      },
    )
  }
}
