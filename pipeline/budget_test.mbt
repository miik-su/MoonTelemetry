///|
test "shared global budget rolls back fanout and retains inflight bytes" {
  let packet = @pipeline.Packet::new(
    @data.from_json(Logs, { "resourceLogs": [{ "schemaUrl": "abcdefgh" }] }),
  )
  let b = @component.MemoryBudget::new(20L)
  let a = @pipeline.Queue::new(capacity=2, max_bytes=100, budget=b)
  let c = @pipeline.Queue::new(capacity=2, max_bytes=100, budget=b)
  assert_true(
    try {
      @pipeline.Fanout::new([a, c]).submit(packet)
      false
    } catch {
      _ => true
    },
  )
  assert_eq(b.used(), 0L)
  assert_true(a.push(packet))
  let retained = b.used()
  let _ = a.take()
  assert_eq(b.used(), retained)
  assert_false(c.push(packet))
  a.discard_all()
  assert_eq(b.used(), 0L)
}
