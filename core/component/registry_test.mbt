///|
test "registry namespaces and duplicate rejection" {
  let r = @component.builtins()
  assert_true(r.contains("otlp", Receiver))
  assert_true(r.contains("otlp", Exporter))
  assert_true(
    try {
      r.register("otlp", Receiver)
      false
    } catch {
      _ => true
    },
  )
}

///|
test "lifecycle never reopens closed admission" {
  let l = @component.Lifecycle::new()
  l.start()
  l.drain()
  assert_eq(l.state(), Draining)
  l.close()
  assert_true(
    try {
      l.start()
      false
    } catch {
      _ => true
    },
  )
}
