///|
fn validate_message(
  bytes : Bytes,
  start : Int32,
  end : Int32,
  kind : String,
  depth : Int32,
  counts : Array[Int32],
  limits~ : Limits = Limits::default(),
) -> Unit raise DataError {
  guard depth <= limits.max_nesting_depth else {
    raise Invalid("OTLP nesting limit exceeded")
  }
  let fields = descriptor(kind)
  if [
      "Log", "Span", "NumberPoint", "HistogramPoint", "ExponentialPoint", "SummaryPoint",
    ].contains(kind) {
    counts[1] += 1
    if counts[1] > limits.max_records_per_request {
      raise Invalid("record limit exceeded")
    }
  }
  let mut attributes = 0
  let mut trace = false
  let mut span = false
  let mut pos = start
  while pos < end {
    counts[0] += 1
    if counts[0] > limits.max_total_fields_per_request {
      raise Invalid("protobuf field limit exceeded")
    }
    let (tag, next) = varint(bytes, pos)
    pos = next
    guard pos <= end && tag >> 3 > 0 && tag >> 3 <= 536870911UL else {
      raise Invalid("invalid protobuf tag")
    }
    let number = (tag >> 3).to_int()
    let wire = (tag & 7).to_int()
    let mut field = None
    for f in fields {
      if f.number == number {
        field = Some(f)
      }
    }
    if field is Some(f) && wire_type(f.kind) != wire {
      raise Invalid("incorrect protobuf wire type for " + f.name)
    }
    if field is Some(f) &&
      (f.name == "attributes" || f.name == "filteredAttributes") {
      attributes += 1
      if attributes > limits.max_attributes_per_record {
        raise Invalid("attribute limit exceeded")
      }
    }
    let len = match wire {
      0 => {
        let (value, next) = varint(bytes, pos)
        pos = next
        if field is Some(f) &&
          f.kind == "uint" &&
          enum_limit(f.name) < 0 &&
          value > 4294967295UL {
          raise Invalid("uint32 overflow")
        }
        0
      }
      1 => 8
      5 => 4
      2 => {
        let (len, next) = varint(bytes, pos)
        pos = next
        guard pos <= end && len <= (end - pos).to_uint64() else {
          raise Invalid("truncated nested protobuf field")
        }
        len.to_int()
      }
      _ => raise Invalid("invalid protobuf wire type")
    }
    guard pos <= end && len <= end - pos else {
      raise Invalid("truncated nested protobuf field")
    }
    if wire == 2 && field is Some(f) {
      if !descriptor(f.kind).is_empty() {
        validate_message(
          bytes,
          pos,
          pos + len,
          f.kind,
          depth + 1,
          counts,
          limits~,
        )
      }
      if f.kind == "id" && len != 0 && len != id_size(f.name) {
        raise Invalid("invalid ID length")
      }
      if f.kind == "id" && len > 0 {
        let mut nonzero = false
        for i in pos..<(pos + len) {
          if bytes[i] != b'\x00' {
            nonzero = true
          }
        }
        if !nonzero {
          raise Invalid("all-zero identifier")
        }
        if f.name == "traceId" {
          trace = true
        }
        if f.name == "spanId" {
          span = true
        }
      }
      if f.kind == "packed64" || f.kind == "packedDouble" {
        if len % 8 != 0 {
          raise Invalid("truncated packed values")
        }
      }
      if f.kind == "packedUInt" {
        let mut p = pos
        while p < pos + len {
          let (_, next) = varint(bytes, p)
          p = next
        }
        if p != pos + len {
          raise Invalid("truncated packed varint")
        }
      }
    }
    pos += len
  }
  if (kind == "Span" || kind == "Link") && (!trace || !span) {
    raise Invalid("span requires nonzero traceId and spanId")
  }
}
