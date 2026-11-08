///|
test "receiver routes exact OTLP paths and negotiates media type" {
  assert_true(@otlp.route("/v1/logs") is Some(Logs))
  assert_true(@otlp.route("/v1/logs/extra") is None)
  assert_eq(@otlp.json_encoding("application/json; charset=utf-8"), Some(true))
  assert_eq(@otlp.json_encoding("application/x-protobuf"), Some(false))
  assert_true(@otlp.json_encoding("text/plain") is None)
}

///|
async test "streaming request body limit" {
  let r = @io.MemoryReader(fn(w) { w.write(b"12345") })
  defer r.close()
  assert_true(
    try {
      let _ = @otlp.read_body(r, 4)
      false
    } catch {
      _ => true
    },
  )
}
