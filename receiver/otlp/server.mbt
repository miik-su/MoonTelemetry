///|
#derive(Debug)
pub(all) suberror RequestError {
  TooLarge
  BadEncoding
}

///|
pub fn route(path : String) -> @data.Signal? {
  match path {
    "/v1/logs" => Some(Logs)
    "/v1/metrics" => Some(Metrics)
    "/v1/traces" => Some(Traces)
    _ => None
  }
}

///|
pub fn json_encoding(content_type : String) -> Bool? {
  match
    content_type.split(";").next().unwrap_or("").trim().to_owned().to_lower() {
    "application/json" => Some(true)
    "application/x-protobuf" => Some(false)
    _ => None
  }
}

///|
pub async fn read_body(
  reader : &@io.Reader,
  limit : Int32,
  idle_timeout_ms~ : Int32 = 10000,
) -> Bytes {
  let b = @buffer.Buffer()
  for ;; {
    match
      @async.with_timeout(idle_timeout_ms, async fn() {
        reader.read_some(max_len=(limit - b.length() + 1).min(8192))
      }) {
      None => break
      Some(chunk) => {
        if chunk.length() > limit - b.length() {
          raise TooLarge
        }
        b.write_bytes(chunk)
      }
    }
  }
  b.to_bytes()
}

///|
pub async fn decompress(body : Bytes, limit : Int32) -> Bytes {
  let source = @io.MemoryReader(async fn(w) { w.write(body) })
  defer source.close()
  let replays : Array[@io.MemoryReader] = []
  defer (for reader in replays {
    reader.close()
  })
  let mut input : &@io.Reader = source
  let output = @buffer.Buffer()
  for _ in 0..<16 {
    let decoder = @gzip.Decoder(input)
    output.write_bytes(read_body(decoder, limit - output.length()))
    match input.read_some(max_len=1) {
      None => return output.to_bytes()
      Some(first) => {
        let previous = input
        let replay = @io.MemoryReader(async fn(w) {
          w.write(first)
          w.write_reader(previous)
        })
        replays.push(replay)
        input = replay
      }
    }
  }
  raise BadEncoding
}

///|
async fn respond(
  conn : @http.ServerConnection,
  code : Int32,
  body : Bytes,
  json : Bool,
  close~ : Bool = false,
) -> Unit {
  let headers = Map::from_array([
    (
      @http.CaseInsensitiveString("Content-Type"),
      if json {
        "application/json"
      } else {
        "application/x-protobuf"
      },
    ),
  ])
  if close {
    headers[@http.CaseInsensitiveString("Connection")] = "close"
  }
  conn.send_response(
    code,
    if code == 200 {
      "OK"
    } else {
      "Request failed"
    },
    extra_headers=headers,
  )
  conn.write(body)
  conn.end_response()
  conn.flush()
}

///|
async fn send_failure(
  conn : @http.ServerConnection,
  code : Int32,
  message : String,
  json : Bool,
  stats : ReceiverStats,
) -> Unit {
  stats.rejected += 1L
  stats.last_status = code
  if code == 408 {
    stats.timeouts += 1L
  }
  let status = match code {
    400 => 3
    401 => 16
    403 => 7
    404 => 5
    405 | 415 => 12
    408 => 4
    413 => 8
    500 => 13
    503 => 14
    _ => 2
  }
  let b = @buffer.Buffer()
  @protobuf.write_uint32(b, 8U)
  @protobuf.write_int32(b, status)
  @protobuf.write_uint32(b, 18U)
  @protobuf.write_string(b, message)
  let body = if json {
    let j : Json = {
      "code": Json::number(status.to_double()),
      "message": Json::string(message),
    }
    @utf8.encode(j.stringify())
  } else {
    b.to_bytes()
  }
  respond(conn, code, body, json, close=true)
  conn.close()
}

///|
async fn handle(
  conn : @http.ServerConnection,
  cfg : @config.ReceiverSpec,
  consume : (@data.Envelope) -> Int32 raise,
  health : () -> Json,
  budget : @component.MemoryBudget,
  requests : @component.MemoryBudget,
  limits : @data.Limits,
  stats : ReceiverStats,
) -> Unit {
  let failure = async fn(conn, code, message, json) {
    send_failure(conn, code, message, json, stats)
  }
  let request = @async.with_timeout(cfg.header_timeout_ms, async fn() {
    conn.read_request()
  })
  stats.requests += 1L
  if !cfg.allowed_ips.is_empty() {
    let peer = conn.client_addr()
    let allowed = cfg.allowed_ips.any(ip => {
      let address = @socket.Addr::parse(
        (if ip.contains(":") { "[" + ip + "]" } else { ip }) + ":\{peer.port()}",
      ) catch {
        _ => return false
      }
      address == peer
    })
    if !allowed {
      failure(conn, 403, "source not allowed", true)
      return
    }
  }
  if request.meth == Get && request.path == "/health" {
    if !cfg.health_enabled {
      failure(conn, 404, "not found", true)
      return
    }
    if !cfg.health_token.is_empty() {
      let supplied = request.headers
        .get(@http.CaseInsensitiveString("Authorization"))
        .unwrap_or("")
      if !token_equal(supplied, "Bearer " + cfg.health_token) {
        failure(conn, 401, "authentication required", true)
        return
      }
    }
    respond(conn, 200, @utf8.encode(health().stringify()), true)
    stats.successes += 1L
    return
  }
  let signal = match route(request.path) {
    Some(s) => s
    None => {
      failure(conn, 404, "unknown endpoint", true)
      return
    }
  }
  let content_type = request.headers
    .get(@http.CaseInsensitiveString("Content-Type"))
    .unwrap_or("")
  let json = match json_encoding(content_type) {
    Some(b) => b
    None => {
      failure(conn, 415, "unsupported content type", true)
      return
    }
  }
  if request.meth != Post {
    failure(conn, 405, "POST required", json)
    return
  }
  if !cfg.auth_token.is_empty() &&
    !token_equal(
      request.headers
      .get(@http.CaseInsensitiveString("Authorization"))
      .unwrap_or(""),
      "Bearer " + cfg.auth_token,
    ) {
    failure(conn, 401, "authentication required", json)
    return
  }
  let encoding = request.headers
    .get(@http.CaseInsensitiveString("Content-Encoding"))
    .unwrap_or("identity")
    .to_lower()
  if encoding != "identity" && encoding != "gzip" {
    failure(conn, 415, "unsupported content encoding", json)
    return
  }
  // Reserve before allocation, covering compressed, expanded and decode buffers.
  let charge = cfg.max_body_bytes.to_int64() * 3L
  if !requests.reserve(charge) {
    failure(conn, 503, "request memory budget exhausted", json)
    return
  }
  defer requests.release(charge)
  if !budget.reserve(charge) {
    failure(conn, 503, "global memory budget exhausted", json)
    return
  }
  defer budget.release(charge)
  let body = try {
    let bytes = read_body(
      conn,
      cfg.max_body_bytes,
      idle_timeout_ms=cfg.body_idle_timeout_ms,
    )
    if encoding == "gzip" {
      decompress(bytes, cfg.max_body_bytes)
    } else {
      bytes
    }
  } catch {
    @async.TimeoutError => {
      failure(conn, 408, "request body idle timeout", json)
      return
    }
    TooLarge => {
      failure(conn, 413, "request body too large", json)
      return
    }
    _ => {
      failure(conn, 400, "invalid request body or gzip stream", json)
      return
    }
  }
  let started = @async.now()
  let input = @data.decode(signal, body, json~, limits~) catch {
    _ => {
      failure(conn, 400, "invalid OTLP payload", json)
      return
    }
  }
  if @async.now() - started > cfg.processing_timeout_ms.to_int64() {
    failure(conn, 503, "parsing time budget exceeded", json)
    return
  }
  let rejected = consume(input) catch {
    @component.NotConfigured => {
      failure(conn, 404, "signal pipeline not configured", json)
      return
    }
    @component.Backpressure(_) | @component.Stopped => {
      failure(conn, 503, "collector busy or draining", json)
      return
    }
    _ => {
      failure(conn, 500, "pipeline failed", json)
      return
    }
  }
  respond(
    conn,
    200,
    @data.response(
      signal,
      rejected~,
      message=if rejected > 0 {
        "filtered by configured processors"
      } else {
        ""
      },
      json~,
    ),
    json,
  )
  stats.successes += 1L
  if request.headers
    .get(@http.CaseInsensitiveString("Connection"))
    .unwrap_or("")
    .to_lower() ==
    "close" {
    conn.close()
  }
}

///|
fn token_equal(a : String, b : String) -> Bool {
  let mut different = a.length() ^ b.length()
  for i in 0..<b.length() {
    different = different |
      ((if i < a.length() { a[i].to_int() } else { 0 }) ^ b[i].to_int())
  }
  different == 0
}

///|
pub async fn serve(
  server : @http.Server,
  cfg : @config.ReceiverSpec,
  consume : (@data.Envelope) -> Int32 raise,
  health~ : () -> Json = () => ({ "status": "ready" } : Json),
  budget~ : @component.MemoryBudget = @component.MemoryBudget::new(1073741824L),
  requests~ : @component.MemoryBudget = @component.MemoryBudget::new(268435456L),
  limits~ : @data.Limits = @data.Limits::default(),
  stats~ : ReceiverStats = ReceiverStats::new(),
) -> Unit {
  let permits = @async.Semaphore(cfg.max_connections)
  @async.with_task_group(async fn(group) {
    for ;; {
      permits.acquire()
      let (conn, _) = {
        errdefer permits.release()
        server.accept()
      }
      group.spawn_bg(async fn() {
        stats.connections += 1
        defer {
          stats.connections -= 1
        }
        defer permits.release()
        defer conn.close()
        for ;; {
          @async.with_timeout(cfg.timeout_ms, async fn() {
            handle(conn, cfg, consume, health, budget, requests, limits, stats)
          }) catch {
            @async.TimeoutError => {
              stats.timeouts += 1L
              stats.rejected += 1L
              stats.last_status = 408
              break
            }
            _ => break
          }
        }
      })
    }
  })
}
