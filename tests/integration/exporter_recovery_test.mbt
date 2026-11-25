///|
async test "OTLP reconnects after real connection loss without losing later batches" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let disconnected = [true]
  let calls = [0]
  let bytes = @fs.read_file("tests/fixtures/logs.json").binary()
  let input = @data.decode(Logs, bytes, json=true)
  let budget = @component.MemoryBudget::new(1000000L)
  @async.with_task_group(group => {
    let mock = group.spawn(async fn() {
      server.run_forever(async fn(_, reader, conn) {
        let _ = reader.read_all()
        calls[0] += 1
        if disconnected[0] {
          conn.close()
          return
        }
        conn.send_response(
          200,
          "OK",
          extra_headers=Map([
            (@http.CaseInsensitiveString("Content-Type"), "application/json"),
          ]),
        )
        conn.write(b"{}")
        conn.end_response()
      })
    })
    defer mock.cancel()
    let destination = @exporter.Destination::new(
      Otlp(
        endpoint="http://127.0.0.1:\{server.addr.port()}",
        json=true,
        timeout_ms=1000,
        retries=1,
      ),
      max_response_bytes=65536,
      total_timeout_ms=3000,
      budget~,
    )
    assert_eq(destination.send(input), input.count())
    assert_eq(calls[0], 2)
    assert_eq(budget.used(), 0L)
    disconnected[0] = false
    assert_eq(destination.send(input), 0)
    assert_eq(calls[0], 3)
    assert_eq(budget.used(), 0L)
    guard destination.stats() is Object(stats) else { abort("missing stats") }
    assert_eq(stats.get("retryAttempts"), Some(Json::string("1")))
    assert_eq(stats.get("failedBatches"), Some(Json::string("1")))
    assert_eq(stats.get("successfulBatches"), Some(Json::string("1")))
    assert_eq(
      stats.get("rejectedRecords"),
      Some(Json::string(input.count().to_string())),
    )
    destination.close()
  })
}
