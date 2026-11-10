///|
async test "request failure and cancellation release shared budgets" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let global = @component.MemoryBudget::new(1000L)
  let requests = @component.MemoryBudget::new(500L)
  let cfg = @config.parse(
    "{\"receivers\":{\"otlp\":{\"max_body_bytes\":128}},\"exporters\":{\"debug\":{}},\"service\":{\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"debug\"]}}}}",
  )
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @otlp.serve(
        server,
        cfg.receivers["otlp"],
        _ => 0,
        budget=global,
        requests~,
      )
    })
    assert_eq(
      post(
        "http://127.0.0.1:\{server.addr.port()}",
        "/v1/logs",
        b"invalid JSON",
        "application/json",
      ),
      400,
    )
    assert_eq(global.used(), 0L)
    assert_eq(requests.used(), 0L)
    let conn = @socket.Tcp::connect(server.addr)
    defer conn.close()
    conn.write(
      "POST /v1/logs HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: 128\r\n\r\n{",
    )
    @async.sleep(30)
    assert_eq(requests.used(), 387L)
    // The second initial read chunk cannot fit the remaining shared budget.
    assert_eq(
      post(
        "http://127.0.0.1:\{server.addr.port()}",
        "/v1/logs",
        b"{}",
        "application/json",
      ),
      503,
    )
    task.cancel()
  })
  assert_eq(global.used(), 0L)
  assert_eq(requests.used(), 0L)
}
