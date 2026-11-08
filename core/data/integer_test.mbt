///|
test "64 bit numeric lexemes retain precision and reject overflow and fractions" {
  for
    literal in [
      "18446744073709551615", "184467440737095516150e-1", "1.8446744073709551615e19",
    ] {
    let body = "{\"resourceLogs\":[{\"scopeLogs\":[{\"logRecords\":[{\"timeUnixNano\":" +
      literal +
      "}]}]}]}"
    let e = @data.decode(Logs, @utf8.encode(body), json=true) catch {
      @data.Invalid(s) => fail(literal + ": " + s)
      e => raise e
    }
    assert_true(e.to_json().stringify().contains("18446744073709551615"))
  }
  for literal in ["18446744073709551616", "1.1", "1e10000", "-1"] {
    let body = "{\"resourceLogs\":[{\"scopeLogs\":[{\"logRecords\":[{\"timeUnixNano\":" +
      literal +
      "}]}]}]}"
    assert_true(
      try {
        let _ = @data.decode(Logs, @utf8.encode(body), json=true)
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      let _ = @data.rejected(Logs, b"", json=true)
      false
    } catch {
      _ => true
    },
  )
}
