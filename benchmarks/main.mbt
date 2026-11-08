///|
async fn main {
  let body = @fs.read_file("tests/fixtures/logs.json").binary()
  let transform = @processor.Transform::Attributes([Delete("authorization")])
  let start = @async.now()
  let mut records = 0
  for _ in 0..<10000 {
    let input = @data.decode(Logs, body, json=true)
    let output = transform.process(input)
    let _ = output.encode(json=false)
    records += output.count()
  }
  let elapsed = (@async.now() - start).max(1L)
  println(
    "{\"iterations\":10000,\"records\":\{records},\"elapsed_ms\":\{elapsed},\"records_per_second\":\{records.to_int64()*1000L/elapsed}}",
  )
}
