///|
pub(all) enum Signal {
  Logs
  Metrics
  Traces
} derive(Eq, Debug)

///|
pub fn Signal::path(self : Signal) -> String {
  match self {
    Logs => "/v1/logs"
    Metrics => "/v1/metrics"
    Traces => "/v1/traces"
  }
}

///|
pub fn signal_from_name(name : String) -> Signal? {
  match name {
    "logs" => Some(Logs)
    "metrics" => Some(Metrics)
    "traces" => Some(Traces)
    _ => None
  }
}

///|
pub(all) enum Envelope {
  Logs(@logs.ExportLogsServiceRequest)
  Metrics(@metrics.ExportMetricsServiceRequest)
  Traces(@traces.ExportTraceServiceRequest)
}

///|
pub fn Envelope::signal(self : Envelope) -> Signal {
  match self {
    Logs(_) => Logs
    Metrics(_) => Metrics
    Traces(_) => Traces
  }
}

///|
pub fn Envelope::to_json(self : Envelope) -> Json raise DataError {
  let json = match self {
    Logs(x) => x.to_json()
    Metrics(x) => x.to_json()
    Traces(x) => x.to_json()
  }
  otlp_json_out(ids(json, false))
}

///|
pub fn Envelope::count(self : Envelope) -> Int32 {
  match self {
    Logs(x) =>
      x.resource_logs.fold(init=0, (n, r) => {
        n + r.scope_logs.fold(init=0, (n, s) => n + s.log_records.length())
      })
    Traces(x) =>
      x.resource_spans.fold(init=0, (n, r) => {
        n + r.scope_spans.fold(init=0, (n, s) => n + s.spans.length())
      })
    Metrics(x) => count_points(x.to_json())
  }
}

///|
fn count_points(j : Json) -> Int32 {
  match j {
    Object(m) =>
      m
      .iter()
      .fold(init=0, (n, kv) => {
        n +
        (if kv.0 == "dataPoints" {
          match kv.1 {
            Array(a) => a.length()
            _ => 0
          }
        } else {
          count_points(kv.1)
        })
      })
    Array(a) => a.fold(init=0, (n, v) => n + count_points(v))
    _ => 0
  }
}

///|
pub(all) suberror DataError {
  Invalid(String)
} derive(Debug)

///|
pub fn from_json(signal : Signal, json : Json) -> Envelope raise {
  validate_json_shape(json, [0, 0], 0)
  decode(signal, json_to_wire(json, root_kind(signal), 0), json=false)
}

///|
pub fn decode(signal : Signal, body : Bytes, json~ : Bool) -> Envelope raise {
  if json {
    let text = @utf8.decode(body)
    validate_json_text(text)
    return from_json(signal, @json.parse(text))
  }
  validate_wire(body)
  validate_message(body, 0, body.length(), root_kind(signal), 0, [0, 0])
  let reader = @protobuf.BytesReader::from_bytes(body)
  let result = match signal {
    Logs => Envelope::Logs(@protobuf.Read::read(reader))
    Metrics => Envelope::Metrics(@protobuf.Read::read(reader))
    Traces => Envelope::Traces(@protobuf.Read::read(reader))
  }
  validate_ids(result.to_json())
  result
}

///|
pub fn Envelope::encode(self : Envelope, json~ : Bool) -> Bytes raise {
  if json {
    return @utf8.encode(self.to_json().stringify())
  }
  let buffer = @buffer.Buffer()
  match self {
    Logs(x) => x.write(buffer)
    Metrics(x) => x.write(buffer)
    Traces(x) => x.write(buffer)
  }
  buffer.to_bytes()
}

///|
fn hex_value(c : UInt16) -> Int32 raise DataError {
  match c {
    '0'..<='9' => c.to_int() - 48
    'a'..<='f' => c.to_int() - 87
    'A'..<='F' => c.to_int() - 55
    _ => raise Invalid("invalid hexadecimal ID")
  }
}

///|
fn id_size(key : String) -> Int32 {
  match key {
    "traceId" => 16
    "spanId" | "parentSpanId" => 8
    _ => 0
  }
}

///|
fn ids(j : Json, inbound : Bool) -> Json raise DataError {
  match j {
    Object(m) => {
      let out = Map([])
      for key, v in m {
        out[key] = if id_size(key) > 0 && v is String(s) {
          if s.is_empty() {
            v
          } else if inbound {
            guard s.length() == id_size(key) * 2 else {
              raise Invalid("invalid ID length: " + key)
            }
            let bytes = Bytes::from_array(
              Array::makei(id_size(key), i => {
                ((hex_value(s[i * 2]) << 4) + hex_value(s[i * 2 + 1])).to_byte()
              }),
            )
            Json::string(@protobuf.base64_encode(bytes))
          } else {
            let bytes = @protobuf.base64_decode(s) catch {
              _ => raise Invalid("invalid base64 ID")
            }
            guard bytes.length() == id_size(key) else {
              raise Invalid("invalid ID length: " + key)
            }
            let digits = "0123456789abcdef"
            let out = StringBuilder()
            for b in bytes {
              out.write_char(digits.get_char(b.to_int() >> 4).unwrap())
              out.write_char(digits.get_char(b.to_int() & 15).unwrap())
            }
            Json::string(out.to_string())
          }
        } else {
          ids(v, inbound)
        }
      }
      Json::object(out)
    }
    Array(a) => Json::array(a.map(v => ids(v, inbound)))
    _ => j
  }
}

///|
fn validate_ids(j : Json) -> Unit raise {
  let _ = ids(j, true)
}
