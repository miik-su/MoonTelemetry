///|
fn validate_message(
  bytes : Bytes,
  start : Int32,
  end : Int32,
  kind : String,
  depth : Int32,
  counts : Array[Int32],
) -> Unit raise DataError {
  guard depth <= 64 else { raise Invalid("OTLP nesting limit exceeded") }
  let fields = descriptor(kind)
  if [
      "Log", "Span", "NumberPoint", "HistogramPoint", "ExponentialPoint", "SummaryPoint",
    ].contains(kind) {
    counts[1] += 1
    if counts[1] > 100000 {
      raise Invalid("record limit exceeded")
    }
  }
  let mut attributes = 0
  let mut pos = start
  while pos < end {
    counts[0] += 1
    if counts[0] > 1000000 {
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
      if attributes > 256 {
        raise Invalid("attribute limit exceeded")
      }
    }
    let len = match wire {
      0 => {
        let (value, next) = varint(bytes, pos)
        pos = next
        if field is Some(f) && f.kind == "uint" && value > 4294967295UL {
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
        validate_message(bytes, pos, pos + len, f.kind, depth + 1, counts)
      }
      if f.kind == "id" && len != 0 && len != id_size(f.name) {
        raise Invalid("invalid ID length")
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
}
