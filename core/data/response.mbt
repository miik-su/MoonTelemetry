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
    return 0L
  }
  let n = if json {
    let j = @json.parse(@utf8.decode(body))
    match signal {
      Logs => {
        let r : @logs.ExportLogsServiceResponse = @json.from_json(j)
        r.partial_success.rejected_log_records
      }
      Metrics => {
        let r : @metrics.ExportMetricsServiceResponse = @json.from_json(j)
        r.partial_success.rejected_data_points
      }
      Traces => {
        let r : @traces.ExportTraceServiceResponse = @json.from_json(j)
        r.partial_success.rejected_spans
      }
    }
  } else {
    validate_wire(body)
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
