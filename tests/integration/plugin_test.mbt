///|
struct Tagged {}

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
