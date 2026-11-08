///|
test "fanout admission is atomic and inflight retains budget" {
  let a = @pipeline.Queue::new(capacity=1, max_bytes=4096)
  let b = @pipeline.Queue::new(capacity=2, max_bytes=4096)
  let f = @pipeline.Fanout::new([a, b])
  let p = @pipeline.Packet::new(@data.from_json(Logs, {}))
  f.submit(p)
  assert_true(a.take() is Some(_))
  assert_true(
    try {
      f.submit(p)
      false
    } catch {
      _ => true
    },
  )
  assert_true(b.take() is Some(_))
  b.finish()
  assert_true(b.take() is None)
  a.finish()
  f.submit(p)
  a.stop()
  assert_false(a.push(p))
}
