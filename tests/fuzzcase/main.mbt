///|
async fn main {
  let args = @env.args()
  guard args.length() == 2 else {
    abort("fuzzcase requires one saved-case path")
  }
  guard @json.parse(@fs.read_file(args[1]).text()) is Object(fields) &&
    fields.get("mode") is Some(String(mode)) &&
    fields.get("bodyBase64") is Some(String(encoded)) else {
    abort("malformed saved fuzz case")
  }
  let bytes = @protobuf.base64_decode(encoded)
  guard bytes.length() <= 65536 else {
    abort("saved fuzz case exceeds harness bound")
  }
  let mut wire_seed : Json = Json::null()
  let mut decoded : @data.Envelope? = None
  let accepted = try {
    match mode {
      "config" => {
        let _ = @config.parse(@utf8.decode(bytes))
        ()
      }
      "gzip" => {
        let _ = @async.with_timeout(200, async fn() {
          @otlp.decompress(bytes, 65536)
        })
        ()
      }
      "json" | "protobuf" => {
        let signal = match fields.get("signal") {
          Some(String(name)) => @data.signal_from_name(name).unwrap_or(Logs)
          _ => Logs
        }
        decoded = Some(@data.decode(signal, bytes, json=mode == "json"))
      }
      _ => abort("unknown saved fuzz mode")
    }
    true
  } catch {
    _ => false
  }
  // Codec failures after successful admission are findings, not invalid-input
  // rejections. Keep these assertions outside the expected-parse-error catch.
  if decoded is Some(envelope) {
    let encoded = envelope.encode(json=false)
    let roundtrip = @data.decode(envelope.signal(), encoded, json=false)
    assert_eq(roundtrip.to_json(), envelope.to_json())
    wire_seed = Json::string(@protobuf.base64_encode(encoded))
  }
  println(
    ({ "accepted": Json::boolean(accepted), "wireSeed": wire_seed } : Json).stringify(),
  )
  @coverage.end()
}
