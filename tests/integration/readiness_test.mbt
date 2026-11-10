///|
async test "readiness reports lifecycle separately from liveness under identical auth" {
  let server = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer server.close()
  let cfg = @config.parse(
    "{\"receivers\":{\"otlp\":{\"health_token\":\"probe-key\"}},\"exporters\":{\"debug\":{}},\"service\":{\"pipelines\":{\"logs\":{\"receivers\":[\"otlp\"],\"processors\":[],\"exporters\":[\"debug\"]}}}}",
  )
  let state = ["created"]
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @otlp.serve(server, cfg.receivers["otlp"], _ => 0, health=() => {
        "status": Json::string(state[0]),
      })
    })
    for status in ["created", "ready", "draining", "closed"] {
      state[0] = status
      for path in ["/health", "/health/live", "/health/ready"] {
        let client = @http.Client("http://127.0.0.1:\{server.addr.port()}")
        defer client.close()
        let response = client.get(
          path,
          extra_headers=Map::from_array([
            (@http.CaseInsensitiveString("Authorization"), "Bearer probe-key"),
          ]),
        )
        assert_eq(
          response.code,
          if path == "/health/ready" && status != "ready" {
            503
          } else {
            200
          },
        )
        let _ = client.read_all()
      }
    }
    for path in ["/health/live", "/health/ready"] {
      let client = @http.Client("http://127.0.0.1:\{server.addr.port()}")
      defer client.close()
      assert_eq(client.get(path).code, 401)
      let _ = client.read_all()
    }
    task.cancel()
  })
}
