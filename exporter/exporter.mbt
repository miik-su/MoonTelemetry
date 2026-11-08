///|
pub struct Destination {
  spec : @config.ExporterSpec
  lock : @async.Mutex
  mut client : @http.Client?
  mut closed : Bool
  max_response_bytes : Int32
}

///|
pub fn Destination::new(
  spec : @config.ExporterSpec,
  max_response_bytes~ : Int32 = 4194304,
) -> Destination {
  {
    spec,
    lock: @async.Mutex(),
    client: None,
    closed: false,
    max_response_bytes,
  }
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
  Transient(Int32)
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
  destination : Destination,
  endpoint : String,
  input : @data.Envelope,
  json : Bool,
  timeout_ms : Int32,
) -> Int32 {
  @async.with_timeout(timeout_ms, async fn() {
    let parsed = @config.endpoint(endpoint)
    let client = match destination.client {
      Some(client) => client
      None => {
        let client = @http.Client(parsed.origin)
        destination.client = Some(client)
        client
      }
    }
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
      parsed.base_path + input.signal().path(),
      body,
      extra_headers=headers,
    )
    if response.code != 200 {
      if retryable(response.code) {
        let delay = retry_after(
          response.headers
          .get(@http.CaseInsensitiveString("Retry-After"))
          .unwrap_or(""),
        )
        raise Transient(delay)
      } else {
        raise Permanent(response.code)
      }
    }
    let media = response.headers
      .get(@http.CaseInsensitiveString("Content-Type"))
      .unwrap_or("")
      .split(";")
      .next()
      .unwrap_or("")
      .trim()
      .to_owned()
      .to_lower()
    if media !=
      (if json { "application/json" } else { "application/x-protobuf" }) {
      raise InvalidResponse
    }
    let bytes = read_bounded(client, destination.max_response_bytes)
    let n = @data.rejected(input.signal(), bytes, json~) catch {
      _ => raise InvalidResponse
    }
    if n > input.count().to_int64() {
      raise InvalidResponse
    }
    if response.headers
      .get(@http.CaseInsensitiveString("Connection"))
      .unwrap_or("")
      .to_lower() ==
      "close" {
      destination.reset_client()
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
  self.lock.acquire()
  defer self.lock.release()
  if self.closed {
    raise Permanent(503)
  }
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
      let line = input.to_json().stringify() + "\n"
      @fs.write_file(path, line, append=true, create_mode=OpenOrCreate)
      0
    }
    RotatingFile(path~, max_bytes~, max_files~) => {
      let line = input.to_json().stringify() + "\n"
      let size = @utf8.encode(line).length().to_int64()
      if size > max_bytes.to_int64() {
        return input.count()
      }
      let current = if @fs.exists(path) { @fs.file_size(path) } else { 0L }
      if current > max_bytes.to_int64() - size {
        for i = max_files - 1; i >= 1; i = i - 1 {
          let old = path + ".\{i}"
          if @fs.exists(old) {
            if i == max_files - 1 {
              @fs.remove(old)
            } else {
              @fs.rename(old, path + ".\{i+1}", replace=true)
            }
          }
        }
        if max_files == 1 {
          @fs.remove(path)
        } else {
          @fs.rename(path, path + ".1", replace=true)
        }
      }
      @fs.write_file(path, line, append=true, create_mode=OpenOrCreate)
      0
    }
    Otlp(endpoint~, json~, timeout_ms~, retries~) =>
      for attempt = 0; ; attempt = attempt + 1 {
        try {
          return send_once(self, endpoint, input, json, timeout_ms)
        } catch {
          Permanent(_) | InvalidResponse => {
            self.reset_client()
            return input.count()
          }
          e => {
            self.reset_client()
            if @async.is_being_cancelled() {
              raise e
            }
            if attempt >= retries {
              return input.count()
            }
            let floor = match e {
              Transient(delay) => delay
              _ => 0
            }
            let jitter = match @env.rand(1) {
              Some(b) => b[0].to_int() * retry_delay(attempt) / 510
              None => 0
            }
            @async.sleep((retry_delay(attempt) + jitter).max(floor))
          }
        }
      }
  }
}

///|
pub async fn Destination::close(self : Destination) -> Unit {
  self.lock.acquire()
  defer self.lock.release()
  if self.closed {
    return
  }
  self.closed = true
  self.reset_client()
  if self.spec is Plugin(destination) {
    destination.close()
  }
}

///|
fn Destination::reset_client(self : Destination) -> Unit {
  if self.client is Some(client) {
    client.close()
  }
  self.client = None
}

///|
pub fn retry_after(value : String, now_ms~ : Int64 = @async.now()) -> Int32 {
  let mut seconds = 0
  if value.is_empty() {
    return 0
  }
  for c in value {
    if c < '0' || c > '9' {
      return date_delay(value, now_ms)
    }
    seconds = (seconds * 10 + c.to_int() - 48).min(3600)
  }
  seconds * 1000
}
