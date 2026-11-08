///|
async test "deterministic gzip mutations remain bounded without panic" {
  let reader = @io.MemoryReader(async fn(writer) {
    let encoder = @gzip.Encoder(writer)
    encoder.write("bounded synthetic gzip payload")
    encoder.end()
  })
  defer reader.close()
  let seed = @otlp.read_body(reader, 1024)
  let mut state = 0x719c4321U
  for i in 0..<300 {
    state = state * 1664525U + 1013904223U
    let pos = (state % seed.length().reinterpret_as_uint()).reinterpret_as_int()
    let bytes = if i % 3 == 0 {
      seed[:pos].to_owned()
    } else {
      Bytes::from_array(
        Array::makei(seed.length(), j => {
          if j == pos {
            seed[j] ^ (1U << (i % 8)).to_byte()
          } else {
            seed[j]
          }
        }),
      )
    }
    let decoded = Some(
      @async.with_timeout(100, async fn() { @otlp.decompress(bytes, 128) }),
    ) catch {
      @async.TimeoutError =>
        abort("small bounded gzip mutation exceeded deadline")
      _ => None
    }
    if decoded is Some(output) {
      assert_true(output.length() <= 128)
    }
  }
}

///|
async test "gzip member cap prevents unbounded member traversal" {
  let reader = @io.MemoryReader(async fn(writer) {
    for _ in 0..<17 {
      let encoder = @gzip.Encoder(writer)
      encoder.write("x")
      encoder.end()
    }
  })
  defer reader.close()
  let input = @otlp.read_body(reader, 4096)
  assert_true(
    try {
      let _ = @otlp.decompress(input, 128)
      false
    } catch {
      _ => true
    },
  )
}
