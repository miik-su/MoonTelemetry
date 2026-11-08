///|
struct SlowClose {
  counts : Array[Int32]
  slow : Bool
}

///|
impl @component.Exporter for SlowClose with fn send(_, _) {
  0
}

///|
impl @component.Exporter for SlowClose with fn close(self) {
  if self.slow {
    @async.sleep(5000)
  } else {
    self.counts[0] += 1
  }
}

///|
async test "one timed out plugin close cannot prevent another from closing" {
  let counts = [0]
  let factories = @component.Factories::new()
  factories.register_exporter("slow", _ => SlowClose::{ counts, slow: true, })
  factories.register_exporter("fast", _ => SlowClose::{ counts, slow: false, })
  let config = @config.parse(
    "{\"receivers\":{\"otlp\":{\"port\":24326}},\"exporters\":{\"slow\":{},\"fast\":{}},\"service\":{\"shutdown_timeout_ms\":50,\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"slow\",\"fast\"]}}}}",
    factories~,
  )
  let runtime = @service.Runtime::new(config)
  runtime.run(stop_after_ms=50)
  assert_eq(counts[0], 1)
}
