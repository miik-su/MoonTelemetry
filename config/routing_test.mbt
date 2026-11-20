///|
test "routing requires valid attached targets and explicit fallback" {
  let rule =
    #|{"exporter":"debug/a","condition":{"attribute":"tier","operator":"exists"}}
  let good = "[" + rule + "]"
  let config = (rules : String, defaults : String) => {
    let source =
      $|{"receivers":{"otlp":{}},"exporters":{"debug/a":{},"debug/b":{}},
      $| "processors":{},"service":{"pipelines":{"logs":{"receivers":["otlp"],"processors":[],"exporters":["debug/a","debug/b"],
      $| "routing":{"rules":\{rules},"default_exporters":\{defaults}}}}}}
    source
  }
  let parsed = @config.parse(config(good, "[\"debug/b\"]"))
  assert_true(parsed.pipelines[0].routing is Some(_))
  for
    (rules, defaults) in [
      (good, "[]"),
      (good, "[\"debug/a\"]"),
      (good, "[\"debug/nope\"]"),
      (good.replace(old="debug/a", new="debug/nope"), "[\"debug/b\"]"),
      (good.replace(old="exists", new="unknown"), "[\"debug/b\"]"),
      ("[" + Array::make(17, rule).join(",") + "]", "[\"debug/b\"]"),
    ] {
    assert_true(
      try {
        let _ = @config.parse(config(rules, defaults))
        false
      } catch {
        _ => true
      },
    )
  }
}
