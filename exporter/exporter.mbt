///|
pub struct Destination {
  spec : @config.ExporterSpec
  lock : @async.Mutex
}

///|
pub fn Destination::new(spec : @config.ExporterSpec) -> Destination {
  { spec, lock: @async.Mutex(), }
}

///|
pub fn retryable(code : Int32) -> Bool {
  code == 429 || code == 502 || code == 503 || code == 504
}

///|
pub fn retry_delay(attempt : Int32) -> Int32 {
  100 * (1 << attempt.max(0).min(6))
}

///|
pub(all) suberror ExportError {
  Permanent(Int32)
  Transient
  InvalidResponse
} derive(Debug)

///|
pub async fn read_bounded(reader : &@io.Reader, max_bytes : Int32) -> Bytes {
  let out = @buffer.Buffer()
  for ;; {
    match reader.read_some(max_len=(max_bytes - out.length() + 1).min(8192)) {
      None => break
      Some(chunk) => {
        if chunk.length() > max_bytes - out.length() {
          raise InvalidResponse
        }
        out.write_bytes(chunk)
      }
    }
  }
  out.to_bytes()
}

///|
async fn send_once(
  endpoint : String,
  input : @data.Envelope,
  json : Bool,
  timeout_ms : Int32,
) -> Int32 {
  @async.with_timeout(timeout_ms, async fn() {
    let client = @http.Client(endpoint)
    defer client.close()
    let body = input.encode(json~)
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
    let response = client.post(
      input.signal().path(),
      body,
      extra_headers=headers,
    )
    if response.code != 200 {
      if retryable(response.code) {
        raise Transient
      } else {
        raise Permanent(response.code)
      }
    }
    let bytes = read_bounded(client, 1048576)
    let n = @data.rejected(input.signal(), bytes, json~) catch {
      _ => raise InvalidResponse
    }
    if n > input.count().to_int64() {
      raise InvalidResponse
    }
    n.to_int()
  })
}

///|
// Return rejected item count. Successful partial responses are never retried.
pub async fn Destination::send(
  self : Destination,
  input : @data.Envelope,
) -> Int32 {
  match self.spec {
    Plugin(destination) => destination.send(input)
    Debug(detailed~) => {
      if detailed {
        println(input.to_json().stringify())
      } else {
        println("\{input.signal().path()} records=\{input.count()}")
      }
      0
    }
    File(path) => {
      self.lock.acquire()
      defer self.lock.release()
      let line = input.to_json().stringify() + "\n"
      @fs.write_file(path, line, append=true, create_mode=OpenOrCreate)
      0
    }
    Otlp(endpoint~, json~, timeout_ms~, retries~) =>
      for attempt = 0; ; attempt = attempt + 1 {
        try {
          return send_once(endpoint, input, json, timeout_ms)
        } catch {
          Permanent(_) | InvalidResponse => return input.count()
          _ => {
            if @async.is_being_cancelled() {
              raise Transient
            }
            if attempt >= retries {
              return input.count()
            }
            @async.sleep(retry_delay(attempt))
          }
        }
      }
  }
}

///|
pub async fn Destination::close(self : Destination) -> Unit {
  if self.spec is Plugin(destination) {
    destination.close()
  }
}
