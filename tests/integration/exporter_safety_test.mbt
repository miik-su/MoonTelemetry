///|
async test "file rotation enforces byte and retention limits" {
  let dir = @fs.tmpdir(prefix="moontelemetry-rotation-")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/out.jsonl"
  let destination = @exporter.Destination::new(
    RotatingFile(path~, max_bytes=160, max_files=3),
  )
  let input = @data.from_json(Logs, {
    "resourceLogs": [
      { "scopeLogs": [{ "logRecords": [{ "body": { "stringValue": "x" } }] }] },
    ],
  })
  for _ in 0..<8 {
    assert_eq(destination.send(input), 0)
  }
  assert_true(@fs.file_size(path) <= 160L)
  assert_true(@fs.exists(path + ".1"))
  assert_true(@fs.exists(path + ".2"))
  assert_false(@fs.exists(path + ".3"))
  destination.close()
}

///|
async test "file failures report safe categories and rejected records" {
  let dir = @fs.tmpdir(prefix="moontelemetry-file-errors-")
  defer @fs.rmdir(dir, recursive=true)
  let input = @data.decode(
    Logs,
    @fs.read_file("tests/fixtures/logs.json").binary(),
    json=true,
  )
  let small = @exporter.Destination::new(
    RotatingFile(path=dir + "/small.jsonl", max_bytes=1, max_files=1),
  )
  assert_eq(small.send(input), input.count())
  assert_false(@fs.exists(dir + "/small.jsonl"))
  guard small.stats() is Object(stats) else { abort("missing file stats") }
  assert_eq(
    stats.get("lastErrorClass"),
    Some(Json::string("file_line_too_large")),
  )
  assert_eq(
    stats.get("rejectedRecords"),
    Some(Json::string(input.count().to_string())),
  )
  small.close()
  let missing = @exporter.Destination::new(
    File(dir + "/missing/private-name.jsonl"),
  )
  assert_true(
    try {
      let _ = missing.send(input)
      false
    } catch {
      _ => true
    },
  )
  guard missing.stats() is Object(failed) else {
    abort("missing failure stats")
  }
  assert_eq(failed.get("lastErrorClass"), Some(Json::string("file_io_error")))
  assert_eq(failed.get("failedBatches"), Some(Json::string("1")))
  assert_eq(
    failed.get("rejectedRecords"),
    Some(Json::string(input.count().to_string())),
  )
  assert_false(missing.stats().stringify().contains("private-name"))
  missing.close()
}

///|
struct SerialExporter {
  active : Array[Int32]
}

///|
impl @component.Exporter for SerialExporter with fn send(self, _) {
  self.active[0] += 1
  defer {
    self.active[0] -= 1
  }
  assert_eq(self.active[0], 1)
  @async.sleep(20)
  0
}

///|
impl @component.Exporter for SerialExporter with fn close(self) {
  self.active[1] += 1
}

///|
async test "plugin sends serialize and close executes once" {
  let active = [0, 0]
  let destination = @exporter.Destination::new(
    Plugin(SerialExporter::{ active, }),
  )
  let empty = @data.from_json(Logs, {})
  @async.with_task_group(group => {
    for _ in 0..<4 {
      group.spawn_bg(async fn() { let _ = destination.send(empty) })
    }
  })
  destination.close()
  destination.close()
  assert_eq(active, [0, 1])
  assert_true(
    try {
      let _ = destination.send(empty)
      false
    } catch {
      _ => true
    },
  )
}

///|
async test "OTLP sessions reuse a connection and invalid media never retries" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let peers : Map[String, Bool] = Map([])
  let calls = [0]
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      server.run_forever(async fn(_, reader, conn) {
        let _ = reader.read_all()
        peers[conn.client_addr().to_string()] = true
        calls[0] += 1
        conn.send_response(
          200,
          "OK",
          extra_headers=Map::from_array([
            (
              @http.CaseInsensitiveString("Content-Type"),
              if calls[0] == 3 {
                "text/plain"
              } else {
                "application/json"
              },
            ),
          ]),
        )
        conn.write(b"{}")
        conn.end_response()
      })
    })
    let destination = @exporter.Destination::new(
      Otlp(
        endpoint="http://127.0.0.1:\{server.addr.port()}",
        json=true,
        timeout_ms=1000,
        retries=3,
      ),
    )
    let input = @data.decode(
      Logs,
      @fs.read_file("tests/fixtures/logs.json").binary(),
      json=true,
    )
    assert_eq(destination.send(input), 0)
    assert_eq(destination.send(input), 0)
    assert_eq(peers.length(), 1)
    assert_eq(destination.send(input), 1)
    assert_eq(calls[0], 3)
    destination.close()
    task.cancel()
  })
}
