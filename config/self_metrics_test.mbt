///|
test "self metrics require a dedicated OTLP exporter and bounded settings" {
  let config = (target : String, instance : String, interval : Int32) => {
    let source =
      $|{"receivers":{"otlp":{}},"processors":{},
      $| "exporters":{"debug":{},"otlp/self":{"endpoint":"http://127.0.0.1:14318"},"otlp/shared":{"endpoint":"http://127.0.0.1:24318"}},
      $| "service":{"pipelines":{"logs":{"receivers":["otlp"],"processors":[],"exporters":["debug","otlp/shared"]}},
      $| "self_metrics":{"exporter":"\{target}","instance_id":"\{instance}","interval_ms":\{interval}}}}
    source
  }
  let parsed = @config.parse(config("otlp/self", "collector-1", 1000))
  assert_true(parsed.self_metrics is Some(spec) && spec.interval_ms == 1000)
  for
    (target, instance, interval) in [
      ("otlp/shared", "collector-1", 1000),
      ("debug", "collector-1", 1000),
      ("otlp/missing", "collector-1", 1000),
      ("otlp/self", "", 1000),
      ("otlp/self", "host:1", 1000),
      ("otlp/self", "collector-1", 999),
      ("otlp/self", "collector-1", 3600001),
    ] {
    assert_true(
      try {
        let _ = @config.parse(config(target, instance, interval))
        false
      } catch {
        _ => true
      },
    )
  }
}
