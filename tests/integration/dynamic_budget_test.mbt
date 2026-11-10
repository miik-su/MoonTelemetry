///|
async test "32 small simultaneous requests fit a budget below one maximum body" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let cfg = @config.parse(
    "{\"receivers\":{\"otlp\":{\"max_connections\":64}},\"exporters\":{\"debug\":{}},\"service\":{\"request_memory_budget_bytes\":2097152,\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"debug\"]}}}}",
  )
  let requests = @component.MemoryBudget::new(2097152L)
  let global = @component.MemoryBudget::new(4194304L)
  let consumed = [0]
  let peers : Array[@socket.Tcp] = []
  defer (for peer in peers {
    peer.close()
  })
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @otlp.serve(
        server,
        cfg.receivers["otlp"],
        _ => {
          consumed[0] += 1
          0
        },
        budget=global,
        requests~,
      )
    })
    for _ in 0..<32 {
      let peer = @socket.Tcp::connect(server.addr)
      peers.push(peer)
      peer.write(
        "POST /v1/logs HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{",
      )
    }
    @async.with_timeout(2000, async fn() {
      while requests.used() < 32L * 24576L {
        @async.sleep(5)
      }
    })
    assert_true(requests.used() < 2097152L)
    for peer in peers {
      peer.write("}")
    }
    for peer in peers {
      let response = @async.with_timeout(2000, async fn() { peer.read_all() })
      assert_true(response.text().contains("200 OK"))
    }
    assert_eq(consumed[0], 32)
    assert_eq(requests.used(), 0L)
    assert_eq(global.used(), 0L)
    task.cancel()
  })
}

///|
async test "mid-read budget exhaustion rejects before parsing and releases prior growth" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let cfg = @config.parse(
    "{\"receivers\":{\"otlp\":{}},\"exporters\":{\"debug\":{}},\"service\":{\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"debug\"]}}}}",
  )
  let requests = @component.MemoryBudget::new(24576L)
  let global = @component.MemoryBudget::new(60000L)
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @otlp.serve(
        server,
        cfg.receivers["otlp"],
        _ => abort("payload must not reach consumer"),
        budget=global,
        requests~,
      )
    })
    let peer = @socket.Tcp::connect(server.addr)
    defer peer.close()
    peer.write(
      "POST /v1/logs HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: 16384\r\n\r\n{",
    )
    let response = @async.with_timeout(2000, async fn() { peer.read_all() })
    assert_true(response.text().contains("503"))
    assert_eq(requests.used(), 0L)
    assert_eq(global.used(), 0L)
    task.cancel()
  })
}
