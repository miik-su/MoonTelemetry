///|
// OTLP JSON field dispatch for the pinned upstream models. This adapter keeps
// oneof field identity: upstream 0.1.8 FromJson guesses by value shape.
// Models and binary serialization remain owned by the upstream dependency.
priv struct Field {
  number : Int32
  name : String
  kind : String
  repeated : Bool
}

///|
let descriptor_cache : Map[String, Array[Field]] = Map([])

///|
fn descriptor(kind : String) -> Array[Field] {
  match descriptor_cache.get(kind) {
    Some(fields) => fields
    None => {
      let fields = build_descriptor(kind)
      descriptor_cache[kind] = fields
      fields
    }
  }
}

///|
fn build_descriptor(kind : String) -> Array[Field] {
  let spec = match kind {
    "Logs" => "1:resourceLogs:ResourceLogs[]"
    "Metrics" => "1:resourceMetrics:ResourceMetrics[]"
    "Traces" => "1:resourceSpans:ResourceSpans[]"
    "ResourceLogs" =>
      "1:resource:Resource 2:scopeLogs:ScopeLogs[] 3:schemaUrl:str"
    "ResourceMetrics" =>
      "1:resource:Resource 2:scopeMetrics:ScopeMetrics[] 3:schemaUrl:str"
    "ResourceSpans" =>
      "1:resource:Resource 2:scopeSpans:ScopeSpans[] 3:schemaUrl:str"
    "ScopeLogs" => "1:scope:Scope 2:logRecords:Log[] 3:schemaUrl:str"
    "ScopeMetrics" => "1:scope:Scope 2:metrics:Metric[] 3:schemaUrl:str"
    "ScopeSpans" => "1:scope:Scope 2:spans:Span[] 3:schemaUrl:str"
    "Resource" =>
      "1:attributes:KeyValue[] 2:droppedAttributesCount:uint 3:entityRefs:EntityRef[]"
    "EntityRef" =>
      "1:schemaUrl:str 2:type:str 3:idKeys:str[] 4:descriptionKeys:str[]"
    "Scope" =>
      "1:name:str 2:version:str 3:attributes:KeyValue[] 4:droppedAttributesCount:uint"
    "KeyValue" => "1:key:str 2:value:AnyValue 3:keyStrindex:uint"
    "AnyValue" =>
      "1:stringValue:str 2:boolValue:bool 3:intValue:int64 4:doubleValue:double 5:arrayValue:ArrayValue 6:kvlistValue:KeyValueList 7:bytesValue:bytes 8:stringValueStrindex:uint"
    "ArrayValue" => "1:values:AnyValue[]"
    "KeyValueList" => "1:values:KeyValue[]"
    "Log" =>
      "1:timeUnixNano:f64 11:observedTimeUnixNano:f64 2:severityNumber:uint 3:severityText:str 5:body:AnyValue 6:attributes:KeyValue[] 7:droppedAttributesCount:uint 8:flags:fixed32 9:traceId:id 10:spanId:id 12:eventName:str"
    "Span" =>
      "1:traceId:id 2:spanId:id 3:traceState:str 4:parentSpanId:id 16:flags:fixed32 5:name:str 6:kind:uint 7:startTimeUnixNano:f64 8:endTimeUnixNano:f64 9:attributes:KeyValue[] 10:droppedAttributesCount:uint 11:events:Event[] 12:droppedEventsCount:uint 13:links:Link[] 14:droppedLinksCount:uint 15:status:Status"
    "Event" =>
      "1:timeUnixNano:f64 2:name:str 3:attributes:KeyValue[] 4:droppedAttributesCount:uint"
    "Link" =>
      "1:traceId:id 2:spanId:id 3:traceState:str 4:attributes:KeyValue[] 5:droppedAttributesCount:uint 6:flags:fixed32"
    "Status" => "2:message:str 3:code:uint"
    "Metric" =>
      "1:name:str 2:description:str 3:unit:str 12:metadata:KeyValue[] 5:gauge:Gauge 7:sum:Sum 9:histogram:Histogram 10:exponentialHistogram:ExponentialHistogram 11:summary:Summary"
    "Gauge" => "1:dataPoints:NumberPoint[]"
    "Sum" =>
      "1:dataPoints:NumberPoint[] 2:aggregationTemporality:uint 3:isMonotonic:bool"
    "Histogram" => "1:dataPoints:HistogramPoint[] 2:aggregationTemporality:uint"
    "ExponentialHistogram" =>
      "1:dataPoints:ExponentialPoint[] 2:aggregationTemporality:uint"
    "Summary" => "1:dataPoints:SummaryPoint[]"
    "NumberPoint" =>
      "7:attributes:KeyValue[] 2:startTimeUnixNano:f64 3:timeUnixNano:f64 5:exemplars:Exemplar[] 8:flags:uint 4:asDouble:double 6:asInt:sf64"
    "HistogramPoint" =>
      "9:attributes:KeyValue[] 2:startTimeUnixNano:f64 3:timeUnixNano:f64 4:count:f64 5:sum:double 6:bucketCounts:packed64 7:explicitBounds:packedDouble 8:exemplars:Exemplar[] 10:flags:uint 11:min:double 12:max:double"
    "ExponentialPoint" =>
      "1:attributes:KeyValue[] 2:startTimeUnixNano:f64 3:timeUnixNano:f64 4:count:f64 5:sum:double 6:scale:sint 7:zeroCount:f64 8:positive:Buckets 9:negative:Buckets 10:flags:uint 11:exemplars:Exemplar[] 12:min:double 13:max:double 14:zeroThreshold:double"
    "Buckets" => "1:offset:sint 2:bucketCounts:packedUInt"
    "SummaryPoint" =>
      "7:attributes:KeyValue[] 2:startTimeUnixNano:f64 3:timeUnixNano:f64 4:count:f64 5:sum:double 6:quantileValues:Quantile[] 8:flags:uint"
    "Quantile" => "1:quantile:double 2:value:double"
    "Exemplar" =>
      "7:filteredAttributes:KeyValue[] 2:timeUnixNano:f64 4:spanId:id 5:traceId:id 3:asDouble:double 6:asInt:sf64"
    _ => ""
  }
  if spec.is_empty() {
    return []
  }
  spec
  .split(" ")
  .map(s => {
    let parts = s.split(":").collect()
    let mut number = 0
    for c in parts[0] {
      number = number * 10 + c.to_int() - 48
    }
    let k = parts[2].to_owned()
    Field::{
      number,
      name: parts[1].to_owned(),
      kind: if k.has_suffix("[]") {
        k[:k.length() - 2].to_owned()
      } else {
        k
      },
      repeated: k.has_suffix("[]"),
    }
  })
  .collect()
}

///|
fn root_kind(signal : Signal) -> String {
  match signal {
    Logs => "Logs"
    Metrics => "Metrics"
    Traces => "Traces"
  }
}

///|
fn wire_type(kind : String) -> Int32 {
  match kind {
    "bool" | "uint" | "uint64" | "int64" | "sint" => 0
    "double" | "f64" | "sf64" => 1
    "fixed32" => 5
    _ => 2
  }
}

///|
fn oneof(kind : String, name : String) -> Bool {
  kind == "AnyValue" ||
  (
    kind == "Metric" &&
    ["gauge", "sum", "histogram", "exponentialHistogram", "summary"].contains(
      name,
    )
  ) ||
  (
    (kind == "NumberPoint" || kind == "Exemplar") &&
    (name == "asDouble" || name == "asInt")
  )
}

///|
fn json_to_wire(j : Json, kind : String, depth : Int32) -> Bytes raise {
  guard depth <= 64 else { raise Invalid("OTLP nesting limit exceeded") }
  guard j is Object(m) else { raise Invalid("expected OTLP object: " + kind) }
  let b = @buffer.Buffer()
  let mut selected = false
  for f in descriptor(kind) {
    if m.get(f.name) is Some(v) && !(v is Null) {
      if oneof(kind, f.name) {
        if selected {
          raise Invalid("multiple oneof fields in " + kind)
        }
        selected = true
      }
      let values = if f.repeated {
        match v {
          Array(a) => a
          _ => raise Invalid("expected array: " + f.name)
        }
      } else {
        [v]
      }
      for v in values {
        @protobuf.write_uint32(
          b,
          ((f.number << 3) + wire_type(f.kind)).reinterpret_as_uint(),
        )
        write_json_field(b, v, f.kind, f.name, depth + 1)
      }
    }
  }
  b.to_bytes()
}

///|
fn write_json_field(
  b : @buffer.Buffer,
  v : Json,
  kind : String,
  name : String,
  depth : Int32,
) -> Unit raise {
  match kind {
    "str" => {
      let s : String = @json.from_json(v)
      @protobuf.write_string(b, s)
    }
    "bool" => {
      let x : Bool = @json.from_json(v)
      @protobuf.write_bool(b, x)
    }
    "uint" | "fixed32" => {
      guard v is Number(n, ..) &&
        n >= 0 &&
        n <= 4294967295.0 &&
        n.to_uint().to_double() == n else {
        raise Invalid("invalid integer or enum: " + name)
      }
      if kind == "uint" {
        @protobuf.write_uint32(b, n.to_uint())
      } else {
        @protobuf.write_fixed32(b, n.to_uint())
      }
    }
    "sint" => {
      let x : Int32 = @json.from_json(v)
      @protobuf.write_sint32(b, x)
    }
    "int64" | "sf64" => {
      let x : Int64 = @json.from_json(v)
      if kind == "int64" {
        @protobuf.write_int64(b, x)
      } else {
        @protobuf.write_sfixed64(b, x)
      }
    }
    "f64" => {
      let x : UInt64 = @json.from_json(v)
      @protobuf.write_fixed64(b, x)
    }
    "double" => {
      let x : Double = @json.from_json(v)
      @protobuf.write_double(b, x)
    }
    "bytes" => {
      let s : String = @json.from_json(v)
      @protobuf.write_bytes(b, @protobuf.base64_decode(s))
    }
    "id" => {
      let s : String = @json.from_json(v)
      guard s.is_empty() || s.length() == id_size(name) * 2 else {
        raise Invalid("invalid ID length: " + name)
      }
      let a = Array::makei(s.length() / 2, i => {
        ((hex_value(s[i * 2]) << 4) + hex_value(s[i * 2 + 1])).to_byte()
      })
      @protobuf.write_bytes(b, Bytes::from_array(a))
    }
    "packed64" | "packedDouble" | "packedUInt" => {
      guard v is Array(a) else { raise Invalid("expected packed array") }
      let packed = @buffer.Buffer()
      for v in a {
        if kind == "packedDouble" {
          let x : Double = @json.from_json(v)
          @protobuf.write_double(packed, x)
        } else {
          let x : UInt64 = @json.from_json(v)
          if kind == "packedUInt" {
            @protobuf.write_uint64(packed, x)
          } else {
            @protobuf.write_fixed64(packed, x)
          }
        }
      }
      @protobuf.write_bytes(b, packed.to_bytes())
    }
    _ => @protobuf.write_bytes(b, json_to_wire(v, kind, depth))
  }
}

///|
fn otlp_json_out(j : Json) -> Json raise DataError {
  match j {
    Object(m) => {
      let out = Map([])
      for k, v in m {
        out[k] = if ["kind", "severityNumber", "aggregationTemporality", "code"].contains(
            k,
          ) &&
          v is String(s) {
          let names = match k {
            "kind" =>
              [
                "SPAN_KIND_UNSPECIFIED", "SPAN_KIND_INTERNAL", "SPAN_KIND_SERVER",
                "SPAN_KIND_CLIENT", "SPAN_KIND_PRODUCER", "SPAN_KIND_CONSUMER",
              ]
            "aggregationTemporality" =>
              [
                "AGGREGATION_TEMPORALITY_UNSPECIFIED", "AGGREGATION_TEMPORALITY_DELTA",
                "AGGREGATION_TEMPORALITY_CUMULATIVE",
              ]
            "code" =>
              ["STATUS_CODE_UNSET", "STATUS_CODE_OK", "STATUS_CODE_ERROR"]
            _ =>
              [
                "SEVERITY_NUMBER_UNSPECIFIED", "SEVERITY_NUMBER_TRACE", "SEVERITY_NUMBER_TRACE2",
                "SEVERITY_NUMBER_TRACE3", "SEVERITY_NUMBER_TRACE4", "SEVERITY_NUMBER_DEBUG",
                "SEVERITY_NUMBER_DEBUG2", "SEVERITY_NUMBER_DEBUG3", "SEVERITY_NUMBER_DEBUG4",
                "SEVERITY_NUMBER_INFO", "SEVERITY_NUMBER_INFO2", "SEVERITY_NUMBER_INFO3",
                "SEVERITY_NUMBER_INFO4", "SEVERITY_NUMBER_WARN", "SEVERITY_NUMBER_WARN2",
                "SEVERITY_NUMBER_WARN3", "SEVERITY_NUMBER_WARN4", "SEVERITY_NUMBER_ERROR",
                "SEVERITY_NUMBER_ERROR2", "SEVERITY_NUMBER_ERROR3", "SEVERITY_NUMBER_ERROR4",
                "SEVERITY_NUMBER_FATAL", "SEVERITY_NUMBER_FATAL2", "SEVERITY_NUMBER_FATAL3",
                "SEVERITY_NUMBER_FATAL4",
              ]
          }
          let mut n = 0
          for i, name in names {
            if name == s {
              n = i
            }
          }
          Json::number(n.to_double())
        } else if k == "bytesValue" {
          let bytes : Bytes = @json.from_json(v) catch {
            _ => raise Invalid("invalid byte representation")
          }
          Json::string(@protobuf.base64_encode(bytes))
        } else {
          otlp_json_out(v)
        }
      }
      Json::object(out)
    }
    Array(a) => Json::array(a.map(otlp_json_out))
    _ => j
  }
}
