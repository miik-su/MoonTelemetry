///|
pub fn response(
  signal : Signal,
  rejected~ : Int32,
  message~ : String = "",
  json~ : Bool,
) -> Bytes raise {
  if rejected == 0 && message.is_empty() {
    return if json { b"{}" } else { b"" }
  }
  let n = rejected.to_int64()
  let buffer = @buffer.Buffer()
  let j = match signal {
    Logs => {
      let r = @logs.ExportLogsServiceResponse::new(
        @logs.ExportLogsPartialSuccess::new(n, message),
      )
      if !json {
        r.write(buffer)
      }
      r.to_json()
    }
    Metrics => {
      let r = @metrics.ExportMetricsServiceResponse::new(
        @metrics.ExportMetricsPartialSuccess::new(n, message),
      )
      if !json {
        r.write(buffer)
      }
      r.to_json()
    }
    Traces => {
      let r = @traces.ExportTraceServiceResponse::new(
        @traces.ExportTracePartialSuccess::new(n, message),
      )
      if !json {
        r.write(buffer)
      }
      r.to_json()
    }
  }
  if json {
    @utf8.encode(j.stringify())
  } else {
    buffer.to_bytes()
  }
}

///|
pub fn rejected(signal : Signal, body : Bytes, json~ : Bool) -> Int64 raise {
  if body.is_empty() {
    if json {
      raise Invalid("empty JSON export response")
    }
    return 0L
  }
  let n = if json {
    let text = @utf8.decode(body)
    validate_json_text(text, Limits::default())
    let j = @json.parse(
      text,
      max_nesting_depth=64,
      reject_duplicate_keys=true,
      preserve_number_repr=true,
    )
    rejected(signal, json_to_wire(j, response_kind(signal), 0), json=false)
  } else {
    validate_wire(body)
    validate_message(body, 0, body.length(), response_kind(signal), 0, [0, 0])
    let r = @protobuf.BytesReader::from_bytes(body)
    match signal {
      Logs => {
        let r : @logs.ExportLogsServiceResponse = @protobuf.Read::read(r)
        r.partial_success.rejected_log_records
      }
      Metrics => {
        let r : @metrics.ExportMetricsServiceResponse = @protobuf.Read::read(r)
        r.partial_success.rejected_data_points
      }
      Traces => {
        let r : @traces.ExportTraceServiceResponse = @protobuf.Read::read(r)
        r.partial_success.rejected_spans
      }
    }
  }
  guard n >= 0 else {
    raise Invalid("negative partial success rejection count")
  }
  n
}

///|
fn response_kind(signal : Signal) -> String {
  match signal {
    Logs => "ResponseLogs"
    Metrics => "ResponseMetrics"
    Traces => "ResponseTraces"
  }
}
