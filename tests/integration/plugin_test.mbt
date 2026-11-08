///|
struct Tagged {}

///|
struct FailingProcessor {}

///|
impl @component.Processor for FailingProcessor with fn process(_, _) {
  raise @component.Configuration("synthetic-private-payload")
}

///|
async test "processor failure identifies component without exposing exception text" {
  let factories = @component.Factories::new()
  factories.register_processor("fail", _ => FailingProcessor::{ })
  let cfg : Json = {
    "receivers": { "otlp": { "port": 24329 } },
    "processors": { "fail/private": {} },
    "exporters": { "debug": {} },
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": ["fail/private"],
          "exporters": ["debug"],
        },
      },
    },
  }
  let runtime = @service.Runtime::new(
    @config.parse(cfg.stringify(), factories~),
  )
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() { runtime.run(stop_after_ms=200) })
    @async.sleep(50)
    assert_eq(
      post(
        "http://127.0.0.1:24329",
        "/v1/logs",
        @fs.read_file("tests/fixtures/logs.json").binary(),
        "application/json",
      ),
      200,
    )
  })
  let health = runtime.health().stringify()
  assert_true(health.contains("\"processorFailedRecords\":\"1\""))
  assert_true(health.contains("\"lastFailureComponentId\":\"fail/private\""))
  assert_true(health.contains("\"lastErrorClass\":\"processor_error\""))
  assert_false(health.contains("synthetic-private-payload"))
  assert_true(health.contains("\"logicalMemoryUsed\":\"0\""))
}

///|
impl @component.Processor for Tagged with fn process(_, input) {
  @processor.Transform::Attributes([Upsert("custom", { "boolValue": true })]).process(
    input,
  )
}

///|
struct Counting {
  counts : Array[Int32]
}

///|
impl @component.Exporter for Counting with fn send(self, input) {
  assert_true(input.to_json().stringify().contains("\"custom\""))
  self.counts[0] += input.count()
  0
}

///|
impl @component.Exporter for Counting with fn close(self) {
  self.counts[1] += 1
}

///|
async test "startup bind failure closes instantiated exporters exactly once" {
  let occupied = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer occupied.close()
  let counts = [0, 0]
  let factories = @component.Factories::new()
  factories.register_exporter("count", _ => Counting::{ counts, })
  let cfg : Json = {
    "receivers": {
      "otlp": { "port": Json::number(occupied.addr.port().to_double()) },
    },
    "exporters": { "count": {} },
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": [],
          "exporters": ["count"],
        },
      },
    },
  }
  let runtime = @service.Runtime::new(
    @config.parse(cfg.stringify(), factories~),
  )
  for _ in 0..<2 {
    assert_true(
      try {
        runtime.run(stop_after_ms=30)
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(counts, [0, 1])
  let health = runtime.health().stringify()
  assert_true(health.contains("\"status\":\"closed\""))
  assert_true(health.contains("\"logicalMemoryUsed\":\"0\""))
}

///|
async test "registered custom components execute without pipeline edits and close once" {
  let factories = @component.Factories::new()
  let counts = [0, 0]
  factories.register_processor("tag", _ => Tagged::{ })
  factories.register_exporter("count", _ => Counting::{ counts, })
  assert_true(
    try {
      factories.register_processor("batch", _ => Tagged::{ })
      false
    } catch {
      _ => true
    },
  )
  let cfg : Json = {
    "receivers": { "otlp": { "port": 24321 } },
    "processors": { "tag": {} },
    "exporters": { "count": {} },
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": ["tag"],
          "exporters": ["count"],
        },
      },
    },
  }
  let runtime = @service.Runtime::new(
    @config.parse(cfg.stringify(), factories~),
  )
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() { runtime.run(stop_after_ms=200) })
    @async.sleep(50)
    assert_eq(
      post(
        "http://127.0.0.1:24321",
        "/v1/logs",
        @fs.read_file("tests/fixtures/logs.json").binary(),
        "application/json",
      ),
      200,
    )
  })
  assert_eq(counts, [1, 1])
}
