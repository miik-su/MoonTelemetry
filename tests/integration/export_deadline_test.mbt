///|
async test "excessive Retry-After abandons rather than retrying early or holding lock" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let calls = [0]
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      server.run_forever(async fn(_, reader, conn) {
        let _ = reader.read_all()
        calls[0] += 1
        conn.send_response(
          503,
          "busy",
          extra_headers=Map::from_array([
            (@http.CaseInsensitiveString("Retry-After"), "3600"),
          ]),
        )
        conn.end_response()
      })
    })
    let budget = @component.MemoryBudget::new(10000000L)
    let destination = @exporter.Destination::new(
      Otlp(
        endpoint="http://127.0.0.1:\{server.addr.port()}",
        json=true,
        timeout_ms=1000,
        retries=3,
      ),
      total_timeout_ms=300,
      max_retry_delay_ms=100,
      budget~,
    )
    let input = @data.decode(
      Logs,
      @fs.read_file("tests/fixtures/logs.json").binary(),
      json=true,
    )
    let start = @async.now()
    for _ in 0..<2 {
      assert_eq(destination.send(input), 1)
    }
    assert_true(@async.now() - start < 1500L)
    assert_eq(calls[0], 2)
    assert_eq(budget.used(), 0L)
    guard destination.stats() is Object(stats) else { abort("missing stats") }
    assert_eq(stats.get("retryAttempts"), Some(Json::string("0")))
    assert_eq(stats.get("failedBatches"), Some(Json::string("2")))
    assert_eq(
      stats.get("lastErrorClass"),
      Some(Json::string("retry_delay_exceeds_deadline_or_policy")),
    )
    destination.close()
    task.cancel()
  })
}

///|
async test "total export deadline cancels active attempt and releases budget and mutex" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let calls = [0]
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      server.run_forever(async fn(_, reader, conn) {
        let _ = reader.read_all()
        calls[0] += 1
        if calls[0] == 1 {
          @async.sleep(2000)
        }
        conn.send_response(
          200,
          "OK",
          extra_headers=Map::from_array([
            (@http.CaseInsensitiveString("Content-Type"), "application/json"),
          ]),
        )
        conn.write(b"{}")
        conn.end_response()
      })
    })
    let budget = @component.MemoryBudget::new(10000000L)
    let destination = @exporter.Destination::new(
      Otlp(
        endpoint="http://127.0.0.1:\{server.addr.port()}",
        json=true,
        timeout_ms=2000,
        retries=3,
      ),
      total_timeout_ms=150,
      budget~,
    )
    let input = @data.decode(
      Logs,
      @fs.read_file("tests/fixtures/logs.json").binary(),
      json=true,
    )
    let start = @async.now()
    assert_eq(destination.send(input), 1)
    assert_true(@async.now() - start < 1500L)
    assert_eq(budget.used(), 0L)
    guard destination.stats() is Object(stats) else { abort("missing stats") }
    assert_eq(
      stats.get("lastErrorClass"),
      Some(Json::string("export_total_timeout")),
    )
    assert_eq(stats.get("failedBatches"), Some(Json::string("1")))
    assert_eq(destination.send(input), 0)
    assert_eq(budget.used(), 0L)
    destination.close()
    task.cancel()
  })
}
