///|
fn enum_limit(name : String) -> Int32 {
  match name {
    "kind" => 5
    "severityNumber" => 24
    "aggregationTemporality" => 2
    "code" => 2
    _ => -1
  }
}

///|
// A descriptor-driven fallback retains future enum numbers that the pinned
// generated enum types cannot represent. Known payloads keep generated models.
fn wire_json(bytes : BytesView, kind : String) -> Json raise {
  let out : Map[String, Json] = Map([])
  let mut pos = 0
  while pos < bytes.length() {
    let (tag, next) = varint(bytes, pos)
    pos = next
    let content = pos
    let wire = (tag & 7).to_int()
    let len = match wire {
      0 => {
        let (_, next) = varint(bytes, pos)
        next - pos
      }
      1 => 8
      5 => 4
      2 => {
        let (len, next) = varint(bytes, pos)
        pos = next
        len.to_int()
      }
      _ => raise Invalid("invalid protobuf wire type")
    }
    let end = pos + len
    for f in descriptor(kind) {
      if f.number != (tag >> 3).to_int() {
        continue
      }
      let r = @protobuf.BytesReader::from_bytes(
        if descriptor(f.kind).is_empty() && !f.kind.has_prefix("packed") {
          bytes[content:end].to_owned()
        } else {
          b""
        },
      )
      let value : Json = match f.kind {
        "str" => Json::string(@protobuf.read_string(r))
        "bool" =>
          if @protobuf.read_bool(r) {
            Json::boolean(true)
          } else {
            Json::boolean(false)
          }
        "uint" =>
          Json::number(
            if enum_limit(f.name) >= 0 {
              @protobuf.read_int32(r).to_double()
            } else {
              @protobuf.read_uint32(r).to_double()
            },
          )
        "fixed32" => Json::number(@protobuf.read_fixed32(r).to_double())
        "sint" => Json::number(@protobuf.read_sint32(r).0.to_double())
        "int64" => Json::string(@protobuf.read_int64(r).to_string())
        "sf64" => Json::string(@protobuf.read_sfixed64(r).to_string())
        "f64" => Json::string(@protobuf.read_fixed64(r).to_string())
        "double" => Json(@protobuf.read_double(r))
        "bytes" =>
          Json::string(@protobuf.base64_encode(@protobuf.read_bytes(r)))
        "id" => {
          let j = ids(
            Json::object(
              Map::from_array([
                (
                  f.name,
                  Json::string(@protobuf.base64_encode(@protobuf.read_bytes(r))),
                ),
              ]),
            ),
            false,
          )
          match j {
            Object(m) => m[f.name]
            _ => Json::null()
          }
        }
        "packed64" | "packedDouble" | "packedUInt" => {
          let values = []
          let mut offset = pos
          let reader = @protobuf.BytesReader::from_bytes(
            bytes[pos:end].to_owned(),
          )
          while offset < end {
            if f.kind == "packedUInt" {
              let (v, next) = varint(bytes, offset)
              values.push(Json::string(v.to_string()))
              offset = next
            } else {
              values.push(
                if f.kind == "packedDouble" {
                  Json(@protobuf.read_double(reader))
                } else {
                  Json::string(@protobuf.read_fixed64(reader).to_string())
                },
              )
              offset += 8
            }
          }
          Json::array(values)
        }
        _ => wire_json(bytes[pos:end], f.kind)
      }
      if f.repeated || f.kind.has_prefix("packed") {
        let previous = match out.get(f.name) {
          Some(Array(a)) => a
          _ => []
        }
        if f.kind.has_prefix("packed") && value is Array(a) {
          previous.append(a)
        } else {
          previous.push(value)
        }
        out[f.name] = Json::array(previous)
      } else {
        out[f.name] = value
      }
    }
    pos = end
  }
  Json::object(out)
}

///|
pub fn merge_future(signal : Signal, items : Array[Envelope]) -> Envelope raise {
  let key = match signal {
    Logs => "resourceLogs"
    Metrics => "resourceMetrics"
    Traces => "resourceSpans"
  }
  let resources = []
  let bytes = @buffer.Buffer()
  for item in items {
    bytes.write_bytes(item.encode(json=false))
    if item.to_json() is Object(m) && m.get(key) is Some(Array(a)) {
      resources.append(a)
    }
  }
  Future(
    signal,
    bytes.to_bytes(),
    Json::object(Map::from_array([(key, Json::array(resources))])),
  )
}

///|
fn count_records(j : Json) -> Int32 {
  match j {
    Object(m) =>
      m
      .iter()
      .fold(init=0, (n, pair) => {
        n +
        (if ["logRecords", "spans", "dataPoints"].contains(pair.0) {
          match pair.1 {
            Array(a) => a.length()
            _ => 0
          }
        } else {
          count_records(pair.1)
        })
      })
    Array(a) => a.fold(init=0, (n, v) => n + count_records(v))
    _ => 0
  }
}
