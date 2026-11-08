///|
fn valid() -> String {
  (
    #|{"receivers":{"otlp":{}},"exporters":{"debug":{}},"processors":{},"service":{"pipelines":{"logs":{"receivers":["otlp"],"processors":[],"exporters":["debug"]}}}}
  )
}

///|
test "defaults and missing references" {
  let c = @config.parse(valid())
  assert_eq(c.receivers["otlp"].host, "127.0.0.1")
  assert_eq(c.pipelines.length(), 1)
  assert_true(
    try {
      let _ = @config.parse(
        valid().replace(old="[\"debug\"]", new="[\"missing\"]"),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "duplicate component IDs cannot be silently overwritten" {
  assert_true(
    try {
      let _ = @config.parse("{\"receivers\":{},\"receivers\":{}}")
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      let _ = @config.parse("{\"receivers\":{\"otlp\":{},\"ot\\u006cp\":{}}}")
      false
    } catch {
      _ => true
    },
  )
}

///|
test "unknown fields invalid limits and unresolved environment" {
  for
    source in [
      valid().replace(old="\"otlp\":{}", new="\"otlp\":{\"port\":-1}"),
      valid().replace(old="\"otlp\":{}", new="\"otlp\":{\"typo\":1}"),
      valid().replace(
        old="\"otlp\":{}",
        new="\"otlp\":{\"host\":\"${env:HOST}\"}",
      ),
    ] {
    assert_true(
      try {
        let _ = @config.parse(source)
        false
      } catch {
        _ => true
      },
    )
  }
  let c = @config.parse(
    valid().replace(
      old="\"otlp\":{}",
      new="\"otlp\":{\"host\":\"${env:HOST}\"}",
    ),
    env=_ => Some("0.0.0.0"),
  )
  assert_eq(c.receivers["otlp"].host, "0.0.0.0")
}
