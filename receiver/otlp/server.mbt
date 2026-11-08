///|
pub(all) suberror RequestError {
  TooLarge
  BadEncoding
} derive(Debug)

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
pub async fn read_body(reader : &@io.Reader, limit : Int32) -> Bytes {
  let b = @buffer.Buffer()
  for ;; {
    match reader.read_some(max_len=(limit - b.length() + 1).min(8192)) {
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
  let decoder = @gzip.Decoder(source)
  read_body(decoder, limit)
}

///|
async fn respond(
  conn : @http.ServerConnection,
  code : Int32,
  body : Bytes,
  json : Bool,
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
    (@http.CaseInsensitiveString("Connection"), "close"),
  ])
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
async fn failure(
  conn : @http.ServerConnection,
  code : Int32,
  message : String,
  json : Bool,
) -> Unit {
  let status = if code == 503 { 14 } else { 3 }
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
  respond(conn, code, body, json)
}

///|
async fn handle(
  conn : @http.ServerConnection,
  cfg : @config.ReceiverSpec,
  consume : (@data.Envelope) -> Int32 raise,
  health : () -> Json,
  budget : @component.MemoryBudget,
  requests : @component.MemoryBudget,
) -> Unit {
  let request = conn.read_request()
  if request.meth == Get && request.path == "/health" {
    respond(conn, 200, @utf8.encode(health().stringify()), true)
    return
  }
  let signal = match route(request.path) {
    Some(s) => s
    None => {
      failure(conn, 404, "unknown endpoint", true)
      return
    }
  }
  if request.meth != Post {
    failure(conn, 405, "POST required", true)
    return
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
    let bytes = read_body(conn, cfg.max_body_bytes)
    if encoding == "gzip" {
      decompress(bytes, cfg.max_body_bytes)
    } else {
      bytes
    }
  } catch {
    TooLarge => {
      failure(conn, 413, "request body too large", json)
      return
    }
    _ => {
      failure(conn, 400, "invalid request body or gzip stream", json)
      return
    }
  }
  let input = @data.decode(signal, body, json~) catch {
    _ => {
      failure(conn, 400, "invalid OTLP payload", json)
      return
    }
  }
  let rejected = consume(input) catch {
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
}

///|
pub async fn serve(
  server : @http.Server,
  cfg : @config.ReceiverSpec,
  consume : (@data.Envelope) -> Int32 raise,
  health~ : () -> Json = () => ({ "status": "ready" } : Json),
  budget~ : @component.MemoryBudget = @component.MemoryBudget::new(1073741824L),
  requests~ : @component.MemoryBudget = @component.MemoryBudget::new(268435456L),
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
        defer permits.release()
        defer conn.close()
        @async.with_timeout(cfg.timeout_ms, async fn() {
          handle(conn, cfg, consume, health, budget, requests)
        }) catch {
          _ => ()
        }
      })
    }
  })
}
