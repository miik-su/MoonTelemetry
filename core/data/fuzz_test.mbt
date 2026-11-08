///|
test "bounded deterministic wire mutations do not panic" {
  let mut state = 0x12345678U
  for i in 0..<2000 {
    let bytes = Bytes::from_array(
      Array::makei(i % 64, j => {
        state = state * 1664525U + 1013904223U
        (state >> (j % 4 * 8)).to_byte()
      }),
    )
    for signal in [@data.Signal::Logs, Metrics, Traces] {
      try {
        let e = @data.decode(signal, bytes, json=false)
        let _ = e.encode(json=false)
      } catch {
        _ => ()
      }
    }
  }
}

///|
test "JSON nesting duplicates and truncation are rejected without panic" {
  let mut text = "{}"
  for _ in 0..<70 {
    text = "[" + text + "]"
  }
  assert_true(
    try {
      let _ = @data.decode(Logs, @utf8.encode(text), json=true)
      false
    } catch {
      _ => true
    },
  )
  for
    text in [
      "{\"resourceLogs\":[],\"resourceLogs\":[]}", "{\"resourceLogs\":[", "{\"resourceLogs\":[],\"resource\\u004cogs\":[]}",
    ] {
    assert_true(
      try {
        let _ = @data.decode(Logs, @utf8.encode(text), json=true)
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      let _ = @data.decode(Logs, b"\xff", json=true)
      false
    } catch {
      _ => true
    },
  )
}
