///|
test "deterministic configuration mutations reject safely or preserve resource contracts" {
  let source = "{\"receivers\":{\"otlp\":{}},\"exporters\":{\"debug\":{}},\"service\":{\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"debug\"]}}}}"
  let alphabet = "{}[],:\"/\\ \n0123456789abcdeftru"
  let mut state = 0x84c2b319U
  let mut accepted = 0
  let mut rejected = 0
  for i in 0..<600 {
    state = state * 1664525U + 1013904223U
    let pos = (state % source.length().reinterpret_as_uint()).reinterpret_as_int()
    let replacement = alphabet[(state >> 16).reinterpret_as_int() %
    alphabet.length()].to_string()
    let candidate = if i % 17 == 0 {
      source
    } else if i % 3 == 0 {
      source[:pos].to_owned()
    } else {
      source[:pos].to_owned() + replacement + source[pos + 1:].to_owned()
    }
    let parsed = Some(@config.parse(candidate)) catch { _ => None }
    if parsed is Some(config) {
      accepted += 1
      assert_true(config.pipelines.length() > 0)
      assert_true(
        config.request_memory_budget_bytes <= config.memory_budget_bytes,
      )
      for pipeline in config.pipelines {
        assert_eq(pipeline.processor_ids.length(), pipeline.processors.length())
        assert_true(pipeline.receivers.all(id => config.receivers.contains(id)))
        assert_true(pipeline.exporters.all(id => config.exporters.contains(id)))
      }
    } else {
      rejected += 1
    }
  }
  assert_true(accepted > 0)
  assert_true(rejected > 0)
}
